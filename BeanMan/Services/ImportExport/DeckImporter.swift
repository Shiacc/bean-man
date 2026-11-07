import Foundation
import SwiftData

/// 一条待导入的词（CSV 行解析后的中间态，还没有进数据库）。
struct ImportEntry: Equatable {
    var word: String
    var phonetic: String = ""
    var partOfSpeech: String = ""
    var meaning: String
    var example: String = ""
    var exampleTranslation: String = ""
    var tagsRaw: String = ""
    var note: String = ""
}

/// 单行的问题。导入不中断，逐行记录，最后一起给用户看。
struct ImportIssue: Identifiable, Equatable {
    /// CSV 里的行号（从 1 开始，含表头，和 Excel 里看到的一致）
    let row: Int
    let reason: String

    var id: String { "\(row)-\(reason)" }
}

struct ImportReport: Equatable {
    var deckID: UUID
    var deckName: String
    var imported: Int
    var skippedDuplicate: Int
    var skippedInvalid: Int
    var issues: [ImportIssue]

    var total: Int { imported + skippedDuplicate + skippedInvalid }
    var isEmpty: Bool { imported == 0 }

    var summary: String {
        var parts = ["导入 \(imported) 个"]
        if skippedDuplicate > 0 { parts.append("重复跳过 \(skippedDuplicate) 个") }
        if skippedInvalid > 0 { parts.append("无效跳过 \(skippedInvalid) 个") }
        return parts.joined(separator: "，")
    }
}

enum ImportError: LocalizedError {
    case missingRequiredColumns
    case noValidRows
    case tooManyRows(limit: Int)
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case .missingRequiredColumns:
            return "表头里至少要有一列「单词」和一列「释义」"
        case .noValidRows:
            return "没有可导入的行：单词和释义都不能为空"
        case let .tooManyRows(limit):
            return "一次最多导入 \(limit) 行，请拆分文件"
        case let .unreadable(detail):
            return "读不了这个文件：\(detail)"
        }
    }
}

/// CSV → 词库。只做「解析 + 建对象 + 去重」，不碰界面。
enum DeckImporter {

    static let rowLimit = 20_000

    /// 表头别名表。键是内部字段，值是能被接受的中英文列名（已归一化，见 CSVTable.normalizeHeader）。
    static let aliases: [String: [String]] = [
        "word": ["word", "单词", "词", "term", "词汇"],
        "phonetic": ["phonetic", "音标", "ipa", "pronunciation", "发音"],
        "partofspeech": ["partofspeech", "词性", "pos"],
        "meaning": ["meaning", "释义", "中文", "意思", "definition", "中文释义"],
        "example": ["example", "例句", "sentence"],
        "exampletranslation": ["exampletranslation", "例句翻译", "翻译", "sentencecn"],
        "tags": ["tags", "标签", "tag"],
        "note": ["note", "备注", "notes", "remark", "说明"]
    ]

    // MARK: - 解析

    /// 表头 → 字段 → 列号。
    static func columnIndices(for table: CSVTable) -> [String: Int] {
        let header = table.normalizedHeader
        var result: [String: Int] = [:]
        for (field, names) in aliases {
            if let index = header.firstIndex(where: { names.contains($0) }) {
                result[field] = index
            }
        }
        return result
    }

    /// 把表里的行转成词条，顺便挑出无效行。
    static func entries(from table: CSVTable) -> (entries: [ImportEntry], issues: [ImportIssue]) {
        let columns = columnIndices(for: table)
        guard let wordIndex = columns["word"], let meaningIndex = columns["meaning"] else {
            return ([], [ImportIssue(row: 1, reason: "表头缺少「单词」或「释义」列")])
        }

        var entries: [ImportEntry] = []
        var issues: [ImportIssue] = []

        for (offset, row) in table.rows.enumerated() {
            let lineNumber = offset + 2   // +1 表头，+1 从 1 开始数
            let word = value(row, columns["word"] ?? wordIndex).trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning = value(row, columns["meaning"] ?? meaningIndex).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !word.isEmpty else {
                issues.append(ImportIssue(row: lineNumber, reason: "单词为空"))
                continue
            }
            guard !meaning.isEmpty else {
                issues.append(ImportIssue(row: lineNumber, reason: "「\(word)」缺少释义"))
                continue
            }

            entries.append(ImportEntry(
                word: word,
                phonetic: value(row, columns["phonetic"]),
                partOfSpeech: value(row, columns["partofspeech"]),
                meaning: meaning,
                example: value(row, columns["example"]),
                exampleTranslation: value(row, columns["exampletranslation"]),
                tagsRaw: value(row, columns["tags"]),
                note: value(row, columns["note"])
            ))
        }

        return (entries, issues)
    }

    private static func value(_ row: [String], _ index: Int?) -> String {
        guard let index, index >= 0, index < row.count else { return "" }
        return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 落库

    /// 导入 CSV 文本。`deck` 为 nil 时新建词库，否则追加。
    @discardableResult
    static func importCSV(text: String,
                          deckName: String,
                          appendingTo deck: Deck? = nil,
                          context: ModelContext,
                          now: Date = Date()) throws -> ImportReport {
        let table: CSVTable
        do {
            table = try CSVParser.parse(text)
        } catch {
            throw ImportError.unreadable(error.localizedDescription)
        }

        guard table.rows.count <= rowLimit else {
            throw ImportError.tooManyRows(limit: rowLimit)
        }

        let parsed = entries(from: table)
        guard columnIndices(for: table)["word"] != nil,
              columnIndices(for: table)["meaning"] != nil else {
            throw ImportError.missingRequiredColumns
        }

        let targetDeck: Deck
        if let deck {
            targetDeck = deck
        } else {
            let trimmed = deckName.trimmingCharacters(in: .whitespacesAndNewlines)
            let newDeck = Deck(name: trimmed.isEmpty ? "导入的词库" : trimmed,
                               summary: "从 CSV 导入",
                               sortIndex: nextDeckSortIndex(context),
                               isBuiltIn: false)
            context.insert(newDeck)
            targetDeck = newDeck
        }

        var seen = Set(targetDeck.words.map(\.normalized))
        var nextIndex = (targetDeck.words.map(\.sortIndex).max() ?? -1) + 1
        var imported = 0
        var duplicates = 0
        var invalid = parsed.issues.count

        for entry in parsed.entries {
            let normalized = Word.normalize(entry.word)
            if seen.contains(normalized) {
                duplicates += 1
                continue
            }
            seen.insert(normalized)

            let word = Word(deckID: targetDeck.id,
                            word: entry.word,
                            phonetic: entry.phonetic,
                            partOfSpeech: entry.partOfSpeech,
                            meaning: entry.meaning,
                            example: entry.example,
                            exampleTranslation: entry.exampleTranslation,
                            tagsRaw: entry.tagsRaw,
                            note: entry.note,
                            createdAt: now,
                            sortIndex: nextIndex)
            word.deck = targetDeck
            context.insert(word)
            targetDeck.words.append(word)
            nextIndex += 1
            imported += 1
        }

        if imported == 0 && duplicates == 0 {
            // 全是无效行：把新建的空词库删掉，别留垃圾
            if deck == nil {
                context.delete(targetDeck)
            }
            try? context.save()
            throw ImportError.noValidRows
        }

        // 新增词库时自动选中它，用户回到今日页就能直接学
        if deck == nil, imported > 0 {
            if let settings = try? AppSettingsStore.current(in: context) {
                settings.selectedDeckID = targetDeck.id
                settings.updatedAt = now
            }
        }

        try context.save()

        return ImportReport(deckID: targetDeck.id,
                            deckName: targetDeck.name,
                            imported: imported,
                            skippedDuplicate: duplicates,
                            skippedInvalid: invalid,
                            issues: parsed.issues)
    }

    static func nextDeckSortIndex(_ context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Deck>(sortBy: [SortDescriptor(\.sortIndex, order: .reverse)])
        let decks = (try? context.fetch(descriptor)) ?? []
        return (decks.first?.sortIndex ?? 0) + 1
    }
}