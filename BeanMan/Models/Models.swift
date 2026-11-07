import Foundation
import SwiftData

// MARK: - Deck

/// 词库。内置示例词库 `isBuiltIn = true`，用户导入的词库为 false。
@Model
final class Deck {
    @Attribute(.unique) var id: UUID
    var name: String
    var summary: String
    var createdAt: Date
    var isBuiltIn: Bool
    var sortIndex: Int

    @Relationship(deleteRule: .cascade, inverse: \Word.deck)
    var words: [Word] = []

    init(id: UUID = UUID(),
         name: String,
         summary: String = "",
         createdAt: Date = Date(),
         isBuiltIn: Bool = false,
         sortIndex: Int = 0) {
        self.id = id
        self.name = name
        self.summary = summary
        self.createdAt = createdAt
        self.isBuiltIn = isBuiltIn
        self.sortIndex = sortIndex
    }
}

// MARK: - Word

/// 一个词条。
///
/// 两个反规范化字段（M1/M2）：
/// - `uniqueKey` = "<deckID>|<normalized>"，配合 `@Attribute(.unique)` 在数据库层做到同库不重词。
/// - `deckID` 直接存 UUID，避免 iOS 17 的 `#Predicate` 在可选关系链上失配。
@Model
final class Word {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var uniqueKey: String

    var word: String
    var normalized: String
    var phonetic: String
    var partOfSpeech: String
    var meaning: String
    var example: String
    var exampleTranslation: String
    /// 逗号分隔的标签原文，用计算属性 `tags` 暴露成数组（M7）。
    var tagsRaw: String
    var note: String
    var isFavorite: Bool
    var createdAt: Date
    var sortIndex: Int
    var deckID: UUID

    var deck: Deck?

    @Relationship(deleteRule: .cascade, inverse: \ReviewState.word)
    var reviewState: ReviewState?

    @Relationship(deleteRule: .cascade, inverse: \StudyRecord.word)
    var records: [StudyRecord] = []

    init(id: UUID = UUID(),
         deckID: UUID,
         word: String,
         phonetic: String = "",
         partOfSpeech: String = "",
         meaning: String,
         example: String = "",
         exampleTranslation: String = "",
         tagsRaw: String = "",
         note: String = "",
         isFavorite: Bool = false,
         createdAt: Date = Date(),
         sortIndex: Int = 0) {
        self.id = id
        self.deckID = deckID
        self.word = word
        self.phonetic = phonetic
        self.partOfSpeech = partOfSpeech
        self.meaning = meaning
        self.example = example
        self.exampleTranslation = exampleTranslation
        self.tagsRaw = tagsRaw
        self.note = note
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.sortIndex = sortIndex

        let norm = Word.normalize(word)
        self.normalized = norm
        self.uniqueKey = "\(deckID.uuidString.lowercased())|\(norm)"
    }

    var tags: [String] {
        get { tagsRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        set { tagsRaw = newValue.joined(separator: ",") }
    }

    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

// MARK: - ReviewState

/// 每个词的学习状态。新词没有 ReviewState，第一次评分时才创建（M3）。
@Model
final class ReviewState {
    @Attribute(.unique) var id: UUID
    var wordID: UUID
    var deckID: UUID

    var easeFactor: Double      // 1.3 ... 3.0
    var intervalDays: Int       // 1 ... 365
    var repetitions: Int
    var dueDate: Date
    var lastReviewedAt: Date?
    var lapses: Int

    /// `StudyPhase` 的原始值，避免 SwiftData 枚举迁移坑。
    var phaseRaw: String
    var isSuspended: Bool

    var word: Word?

    init(id: UUID = UUID(),
         wordID: UUID,
         deckID: UUID,
         easeFactor: Double = 2.5,
         intervalDays: Int = 0,
         repetitions: Int = 0,
         dueDate: Date = Date(),
         lastReviewedAt: Date? = nil,
         lapses: Int = 0,
         phase: StudyPhase = .new,
         isSuspended: Bool = false) {
        self.id = id
        self.wordID = wordID
        self.deckID = deckID
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.repetitions = repetitions
        self.dueDate = dueDate
        self.lastReviewedAt = lastReviewedAt
        self.lapses = lapses
        self.phaseRaw = phase.rawValue
        self.isSuspended = isSuspended
    }

    var phase: StudyPhase {
        get { StudyPhase(rawValue: phaseRaw) ?? .new }
        set { phaseRaw = newValue.rawValue }
    }
}

// MARK: - StudyRecord

/// 一次评分的历史记录。随 Word 级联删除（M4），但聚合统计留在 StudySession。
@Model
final class StudyRecord {
    @Attribute(.unique) var id: UUID
    var wordID: UUID
    /// 反规范化：记录所属词库，便于「今日已用多少新词额度」这类按库统计。
    var deckID: UUID
    var ratingRaw: Int
    var wasNew: Bool
    var reviewedAt: Date
    var previousDueDate: Date?
    var newDueDate: Date
    var previousIntervalDays: Int
    var newIntervalDays: Int
    var durationMs: Int

    var word: Word?
    var session: StudySession?

    init(id: UUID = UUID(),
         wordID: UUID,
         deckID: UUID,
         rating: Rating,
         wasNew: Bool,
         reviewedAt: Date = Date(),
         previousDueDate: Date? = nil,
         newDueDate: Date,
         previousIntervalDays: Int = 0,
         newIntervalDays: Int = 0,
         durationMs: Int = 0) {
        self.id = id
        self.wordID = wordID
        self.deckID = deckID
        self.ratingRaw = rating.rawValue
        self.wasNew = wasNew
        self.reviewedAt = reviewedAt
        self.previousDueDate = previousDueDate
        self.newDueDate = newDueDate
        self.previousIntervalDays = previousIntervalDays
        self.newIntervalDays = newIntervalDays
        self.durationMs = durationMs
    }

    var rating: Rating { Rating(rawValue: ratingRaw) ?? .good }
}

// MARK: - StudySession

/// 一次学习会话（一次「开始学习 → 完成」）。独立于 Word 存活，用来保住统计与打卡。
@Model
final class StudySession {
    @Attribute(.unique) var id: UUID
    /// 会话类型：today / wrongBook / quiz。用字符串便于后续扩展。
    var kindRaw: String
    var startedAt: Date
    var endedAt: Date?
    /// `yyyy-MM-dd`，打卡与柱状图只做字符串集合运算（M5）。
    var dayKey: String
    var newWordCount: Int
    var reviewCount: Int
    var answeredCount: Int
    var correctCount: Int

    @Relationship(deleteRule: .cascade, inverse: \StudyRecord.session)
    var records: [StudyRecord] = []

    init(id: UUID = UUID(),
         kind: String = "today",
         startedAt: Date = Date(),
         endedAt: Date? = nil,
         dayKey: String,
         newWordCount: Int = 0,
         reviewCount: Int = 0,
         answeredCount: Int = 0,
         correctCount: Int = 0) {
        self.id = id
        self.kindRaw = kind
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.dayKey = dayKey
        self.newWordCount = newWordCount
        self.reviewCount = reviewCount
        self.answeredCount = answeredCount
        self.correctCount = correctCount
    }
}

// MARK: - AppSettings

/// 用户设置。用 `key = "app"` 的哨兵单例，保证只有一个实例（M6）。
@Model
final class AppSettings {
    @Attribute(.unique) var key: String

    var dailyNewLimit: Int
    var dailyReviewLimit: Int
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var voiceAccentRaw: String
    var autoPlay: Bool
    var onboardingCompleted: Bool
    var selectedDeckID: UUID?
    var schemaVersion: Int
    var updatedAt: Date

    init(key: String = "app",
         dailyNewLimit: Int = 20,
         dailyReviewLimit: Int = 100,
         reminderEnabled: Bool = true,
         reminderHour: Int = 20,
         reminderMinute: Int = 0,
         voiceAccent: VoiceAccent = .american,
         autoPlay: Bool = true,
         onboardingCompleted: Bool = false,
         selectedDeckID: UUID? = nil,
         schemaVersion: Int = 1,
         updatedAt: Date = Date()) {
        self.key = key
        self.dailyNewLimit = dailyNewLimit
        self.dailyReviewLimit = dailyReviewLimit
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.voiceAccentRaw = voiceAccent.rawValue
        self.autoPlay = autoPlay
        self.onboardingCompleted = onboardingCompleted
        self.selectedDeckID = selectedDeckID
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
    }

    var voiceAccent: VoiceAccent {
        get { VoiceAccent(rawValue: voiceAccentRaw) ?? .american }
        set { voiceAccentRaw = newValue.rawValue }
    }
}