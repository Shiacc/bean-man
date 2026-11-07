import Foundation
import SwiftData

/// JSON 备份文件的结构。
///
/// 设计原则：**只存数据，不存实现**。字段名尽量和 @Model 对齐，
/// 这样以后模型改名也能靠 Codable 的默认值兼容旧备份。
struct BackupFile: Codable {
    /// 备份格式版本。以后字段变了就升这个号，读到老版本走兼容分支。
    var schemaVersion: Int
    var exportedAt: Date
    var appVersion: String
    var decks: [DeckPayload]
}

struct DeckPayload: Codable {
    var id: UUID
    var name: String
    var summary: String
    var createdAt: Date
    var isBuiltIn: Bool
    var sortIndex: Int
    var words: [WordPayload]
}

struct WordPayload: Codable {
    var id: UUID
    var word: String
    var phonetic: String
    var partOfSpeech: String
    var meaning: String
    var example: String
    var exampleTranslation: String
    var tags: [String]
    var note: String
    var isFavorite: Bool
    var createdAt: Date
    var sortIndex: Int
    var reviewState: ReviewStatePayload?
}

struct ReviewStatePayload: Codable {
    var easeFactor: Double
    var intervalDays: Int
    var repetitions: Int
    var dueDate: Date
    var lastReviewedAt: Date?
    var lapses: Int
    var phase: String
    var isSuspended: Bool
    var lastRating: Int?
    var wrongBookHiddenAt: Date?
}

/// 恢复结果，给用户看个数。
struct RestoreReport: Equatable {
    var decks: Int
    var words: Int
    var states: Int
    var skippedDecks: Int

    var summary: String {
        var text = "恢复 \(decks) 个词库、\(words) 个词"
        if skippedDecks > 0 { text += "，跳过 \(skippedDecks) 个已存在的词库" }
        return text
    }
}

enum BackupError: LocalizedError {
    case unreadable(String)
    case wrongFormat

    var errorDescription: String? {
        switch self {
        case let .unreadable(detail):
            return "备份文件读不了：\(detail)"
        case .wrongFormat:
            return "这不是豆卡单词的备份文件"
        }
    }
}

/// 导出 / 导入 JSON 备份。
///
/// 只做「模型 ↔ 纯数据」的搬运，所以可以脱离界面单测。
enum BackupService {

    static let currentSchemaVersion = 1

    // MARK: - 导出

    static func makeBackup(context: ModelContext,
                           now: Date = Date(),
                           appVersion: String = BackupService.appVersion) throws -> BackupFile {
        let descriptor = FetchDescriptor<Deck>(sortBy: [SortDescriptor(\.sortIndex)])
        let decks = try context.fetch(descriptor)

        let payloads = decks.map { deck in
            DeckPayload(
                id: deck.id,
                name: deck.name,
                summary: deck.summary,
                createdAt: deck.createdAt,
                isBuiltIn: deck.isBuiltIn,
                sortIndex: deck.sortIndex,
                words: deck.words
                    .sorted { $0.sortIndex < $1.sortIndex }
                    .map { word in
                        WordPayload(
                            id: word.id,
                            word: word.word,
                            phonetic: word.phonetic,
                            partOfSpeech: word.partOfSpeech,
                            meaning: word.meaning,
                            example: word.example,
                            exampleTranslation: word.exampleTranslation,
                            tags: word.tags,
                            note: word.note,
                            isFavorite: word.isFavorite,
                            createdAt: word.createdAt,
                            sortIndex: word.sortIndex,
                            reviewState: word.reviewState.map { state in
                                ReviewStatePayload(
                                    easeFactor: state.easeFactor,
                                    intervalDays: state.intervalDays,
                                    repetitions: state.repetitions,
                                    dueDate: state.dueDate,
                                    lastReviewedAt: state.lastReviewedAt,
                                    lapses: state.lapses,
                                    phase: state.phase.rawValue,
                                    isSuspended: state.isSuspended,
                                    lastRating: state.lastRatingRaw,
                                    wrongBookHiddenAt: state.wrongBookHiddenAt
                                )
                            }
                        )
                    }
            )
        }

        return BackupFile(schemaVersion: currentSchemaVersion,
                          exportedAt: now,
                          appVersion: appVersion,
                          decks: payloads)
    }

    static func encode(_ file: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(file)
    }

    static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(BackupFile.self, from: data)
        } catch {
            throw BackupError.unreadable(error.localizedDescription)
        }
    }

    // MARK: - 导入

    /// 把备份写回数据库。
    ///
    /// 同名同 id 的词库默认跳过（不覆盖用户现在的进度）；`replaceExisting = true` 时才删掉重建。
    @discardableResult
    static func restore(_ file: BackupFile,
                        into context: ModelContext,
                        replaceExisting: Bool = false) throws -> RestoreReport {
        guard file.schemaVersion <= currentSchemaVersion else {
            throw BackupError.wrongFormat
        }

        let existing = try context.fetch(FetchDescriptor<Deck>())
        var existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        var deckCount = 0
        var wordCount = 0
        var stateCount = 0
        var skipped = 0

        for payload in file.decks {
            if let old = existingByID[payload.id] {
                if replaceExisting {
                    context.delete(old)
                    existingByID.removeValue(forKey: payload.id)
                } else {
                    skipped += 1
                    continue
                }
            }

            let deck = Deck(id: payload.id,
                            name: payload.name,
                            summary: payload.summary,
                            createdAt: payload.createdAt,
                            isBuiltIn: payload.isBuiltIn,
                            sortIndex: payload.sortIndex)
            context.insert(deck)
            deckCount += 1

            for wp in payload.words {
                let word = Word(id: wp.id,
                                deckID: deck.id,
                                word: wp.word,
                                phonetic: wp.phonetic,
                                partOfSpeech: wp.partOfSpeech,
                                meaning: wp.meaning,
                                example: wp.example,
                                exampleTranslation: wp.exampleTranslation,
                                tagsRaw: wp.tags.joined(separator: ","),
                                note: wp.note,
                                isFavorite: wp.isFavorite,
                                createdAt: wp.createdAt,
                                sortIndex: wp.sortIndex)
                word.deck = deck
                context.insert(word)
                deck.words.append(word)
                wordCount += 1

                if let sp = wp.reviewState {
                    let state = ReviewState(wordID: word.id,
                                            deckID: deck.id,
                                            easeFactor: sp.easeFactor,
                                            intervalDays: sp.intervalDays,
                                            repetitions: sp.repetitions,
                                            dueDate: sp.dueDate,
                                            lastReviewedAt: sp.lastReviewedAt,
                                            lapses: sp.lapses,
                                            phase: StudyPhase(rawValue: sp.phase) ?? .review,
                                            isSuspended: sp.isSuspended,
                                            lastRatingRaw: sp.lastRating,
                                            wrongBookHiddenAt: sp.wrongBookHiddenAt)
                    word.reviewState = state
                    context.insert(state)
                    stateCount += 1
                }
            }
        }

        // 如果当前选中的词库已经不在了，退回到第一个
        if let settings = try? AppSettingsStore.current(in: context) {
            let stillThere = try context.fetch(FetchDescriptor<Deck>())
                .contains { $0.id == settings.selectedDeckID }
            if !stillThere {
                settings.selectedDeckID = try context.fetch(FetchDescriptor<Deck>())
                    .sorted { $0.sortIndex < $1.sortIndex }
                    .first?.id
            }
        }

        try context.save()
        return RestoreReport(decks: deckCount, words: wordCount, states: stateCount, skippedDecks: skipped)
    }

    // MARK: - 重置

    /// 清空学习进度，保留词库和词条。
    static func resetProgress(context: ModelContext) throws {
        for state in try context.fetch(FetchDescriptor<ReviewState>()) {
            context.delete(state)
        }
        for record in try context.fetch(FetchDescriptor<StudyRecord>()) {
            context.delete(record)
        }
        for session in try context.fetch(FetchDescriptor<StudySession>()) {
            context.delete(session)
        }
        try context.save()
    }

    /// 备份文件名：豆卡单词备份-2026-11-07.json
    static func suggestedFileName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "豆卡单词备份-\(formatter.string(from: now)).json"
    }

    static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}