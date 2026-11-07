import Foundation

/// 一张 CSV 表：表头 + 数据行。
///
/// 纯值类型，不依赖 SwiftData —— 这样解析逻辑可以直接单测，不用起数据库。
struct CSVTable: Equatable {
    var header: [String]
    var rows: [[String]]

    /// 表头归一化：去空格、转小写、去掉 `_` `-` 和空格，便于认列。
    var normalizedHeader: [String] { header.map(CSVTable.normalizeHeader) }

    static func normalizeHeader(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }
}

enum CSVError: LocalizedError, Equatable {
    case emptyFile
    case missingHeader
    case unclosedQuote(line: Int)

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "文件是空的"
        case .missingHeader:
            return "第一行必须是表头，例如 word,phonetic,partOfSpeech,meaning"
        case let .unclosedQuote(line):
            return "第 \(line) 行有一个引号没有闭合"
        }
    }
}

/// 手写 CSV 解析器。
///
/// 支持：UTF-8 BOM、CRLF / LF、双引号包裹的字段、字段内逗号与换行、`""` 转义。
/// 不支持：自定义分隔符之外的花样（够用就好，Excel 导出的就是这套）。
enum CSVParser {

    static func parse(_ text: String, separator: Character = ",") throws -> CSVTable {
        var body = text
        if body.hasPrefix("\u{FEFF}") {
            body.removeFirst()
        }

        let chars = Array(body)
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var line = 1
        var index = 0

        while index < chars.count {
            let char = chars[index]

            if inQuotes {
                if char == "\"" {
                    // 连续两个引号 = 一个字面引号
                    if index + 1 < chars.count, chars[index + 1] == "\"" {
                        field.append("\"")
                        index += 2
                        continue
                    }
                    inQuotes = false
                    index += 1
                    continue
                }
                if char == "\n" { line += 1 }
                field.append(char)
                index += 1
                continue
            }

            switch char {
            case "\"":
                inQuotes = true
                index += 1
            case separator:
                row.append(field)
                field = ""
                index += 1
            case "\r":
                // CRLF：吃掉 \r，交给 \n 收行；单独出现的 \r 也当换行处理
                index += 1
            case "\n":
                row.append(field)
                field = ""
                rows.append(row)
                row = []
                line += 1
                index += 1
            default:
                field.append(char)
                index += 1
            }
        }

        if inQuotes {
            throw CSVError.unclosedQuote(line: line)
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        // 丢掉完全空白的行（Excel 常在末尾留空行）
        rows = rows.filter { line in
            !line.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        }

        guard var header = rows.first else { throw CSVError.emptyFile }
        guard header.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            throw CSVError.missingHeader
        }
        header = header.map { $0.trimmingCharacters(in: .whitespaces) }
        rows.removeFirst()

        // 补齐 / 截断到表头长度，后续按列取值不用再判越界
        let width = header.count
        let normalized = rows.map { line -> [String] in
            var copy = line
            if copy.count < width {
                copy.append(contentsOf: Array(repeating: "", count: width - copy.count))
            } else if copy.count > width {
                copy = Array(copy.prefix(width))
            }
            return copy
        }

        return CSVTable(header: header, rows: normalized)
    }
}