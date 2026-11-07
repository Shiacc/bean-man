import Foundation
import Observation
import SwiftData

/// 8 个本地里程碑。只在本机判定、不上传、不排名。
enum Achievement: String, CaseIterable, Identifiable {
    case firstStep
    case streak7
    case streak30
    case streak100
    case thousandWords
    case mastered500
    case clearedDue
    case firstImport

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstStep: return "起步"
        case .streak7: return "连续 7 天"
        case .streak30: return "连续 30 天"
        case .streak100: return "连续 100 天"
        case .thousandWords: return "千词"
        case .mastered500: return "掌握 500"
        case .clearedDue: return "清空到期"
        case .firstImport: return "首次导入"
        }
    }

    var detail: String {
        switch self {
        case .firstStep: return "完成第一次学习"
        case .streak7: return "连续 7 天有学习"
        case .streak30: return "一个月没断"
        case .streak100: return "一百天，很稳"
        case .thousandWords: return "累计学过 1000 个词"
        case .mastered500: return "500 个词进入长期记忆"
        case .clearedDue: return "把当天到期词清空一次"
        case .firstImport: return "导入第一个自己的词库"
        }
    }

    var icon: String {
        switch self {
        case .firstStep: return "sparkles"
        case .streak7: return "flame.fill"
        case .streak30: return "flame"
        case .streak100: return "crown.fill"
        case .thousandWords: return "text.book.closed.fill"
        case .mastered500: return "checkmark.seal.fill"
        case .clearedDue: return "sun.max.fill"
        case .firstImport: return "square.and.arrow.down.fill"
        }
    }

    /// 进度条的分母。
    var target: Double {
        switch self {
        case .firstStep, .clearedDue, .firstImport: return 1
        case .streak7: return 7
        case .streak30: return 30
        case .streak100: return 100
        case .thousandWords: return 1000
        case .mastered500: return 500
        }
    }
}

/// 判定里程碑用的当前数字。
struct AchievementMetrics: Equatable {
    var learnedWords: Int = 0
    var masteredWords: Int = 0
    var streak: Int = 0
    var clearedDue = false
    var importedDeck = false
}

/// 里程碑中心：判定 + 持久化 + 庆祝状态。
///
/// 存 `UserDefaults`（`achievement.<id>.unlockedAt`），不建表——它只是派生状态，
/// 删库重装后重新判定一次也不会错。
@MainActor
@Observable
final class AchievementCenter {

    static let shared = AchievementCenter()

    private(set) var metrics = AchievementMetrics()
    /// 正在庆祝的那一个（nil = 不显示）
    private(set) var celebrating: Achievement?

    private let defaults: UserDefaults
    private let unlockedKeyPrefix = "achievement."
    private let clearedDueKey = "flag.clearedDue.v1"
    private let importedKey = "flag.importedDeck.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - 查询

    func unlockedAt(_ achievement: Achievement) -> Date? {
        let value = defaults.double(forKey: unlockedKeyPrefix + achievement.rawValue + ".unlockedAt")
        guard value > 0 else { return nil }
        return Date(timeIntervalSince1970: value)
    }

    func isUnlocked(_ achievement: Achievement) -> Bool {
        unlockedAt(achievement) != nil
    }

    var unlockedCount: Int {
        Achievement.allCases.filter { isUnlocked($0) }.count
    }

    /// 0...1，已解锁直接给 1。`metrics` 不传就用最近一次判定的。
    func progress(for achievement: Achievement, metrics override: AchievementMetrics? = nil) -> Double {
        if isUnlocked(achievement) { return 1 }
        let metrics = override ?? self.metrics
        let value: Double
        switch achievement {
        case .firstStep: value = metrics.learnedWords > 0 ? 1 : 0
        case .streak7, .streak30, .streak100: value = Double(metrics.streak)
        case .thousandWords: value = Double(metrics.learnedWords)
        case .mastered500: value = Double(metrics.masteredWords)
        case .clearedDue: value = metrics.clearedDue ? 1 : 0
        case .firstImport: value = metrics.importedDeck ? 1 : 0
        }
        return min(1, max(0, value / achievement.target))
    }

    func progressText(for achievement: Achievement, metrics override: AchievementMetrics? = nil) -> String {
        let metrics = override ?? self.metrics
        switch achievement {
        case .streak7, .streak30, .streak100:
            return "\(min(metrics.streak, Int(achievement.target))) / \(Int(achievement.target)) 天"
        case .thousandWords:
            return "\(min(metrics.learnedWords, 1000)) / 1000 词"
        case .mastered500:
            return "\(min(metrics.masteredWords, 500)) / 500 词"
        case .firstStep:
            return metrics.learnedWords > 0 ? "已完成" : "学一个词就解锁"
        case .clearedDue:
            return metrics.clearedDue ? "已完成" : "当天到期词清零"
        case .firstImport:
            return metrics.importedDeck ? "已完成" : "导入一个 CSV 或备份"
        }
    }

    // MARK: - 判定

    /// 重新计算并解锁。返回本次新解锁的个数。
    @discardableResult
    func check(context: ModelContext, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let metrics = Self.snapshot(context: context, now: now, calendar: calendar, defaults: defaults)
        return check(metrics: metrics, now: now)
    }

    /// 直接喂指标（测试与「不查库的调用方」用）。
    @discardableResult
    func check(metrics: AchievementMetrics, now: Date = Date()) -> Int {
        self.metrics = metrics

        var newly: [Achievement] = []
        for achievement in Achievement.allCases {
            guard !isUnlocked(achievement) else { continue }
            guard reached(achievement, metrics: metrics) else { continue }
            defaults.set(now.timeIntervalSince1970,
                         forKey: unlockedKeyPrefix + achievement.rawValue + ".unlockedAt")
            newly.append(achievement)
        }
        if celebrating == nil, let first = newly.first {
            celebrating = first
        }
        return newly.count
    }

    private func reached(_ achievement: Achievement, metrics: AchievementMetrics) -> Bool {
        switch achievement {
        case .firstStep: return metrics.learnedWords >= 1
        case .streak7: return metrics.streak >= 7
        case .streak30: return metrics.streak >= 30
        case .streak100: return metrics.streak >= 100
        case .thousandWords: return metrics.learnedWords >= 1000
        case .mastered500: return metrics.masteredWords >= 500
        case .clearedDue: return metrics.clearedDue
        case .firstImport: return metrics.importedDeck
        }
    }

    func dismissCelebration() {
        celebrating = nil
    }

    func resetAll() {
        for achievement in Achievement.allCases {
            defaults.removeObject(forKey: unlockedKeyPrefix + achievement.rawValue + ".unlockedAt")
        }
        defaults.removeObject(forKey: clearedDueKey)
        defaults.removeObject(forKey: importedKey)
        metrics = AchievementMetrics()
        celebrating = nil
    }

    // MARK: - 外部事件

    /// 把当天到期词清空一次（今日页在 due 归零且有学习记录时调用）。
    func markClearedDue() {
        if !defaults.bool(forKey: clearedDueKey) {
            defaults.set(true, forKey: clearedDueKey)
        }
    }

    /// 导入成功一次。
    func markImportedDeck() {
        if !defaults.bool(forKey: importedKey) {
            defaults.set(true, forKey: importedKey)
        }
    }

    // MARK: - 快照

    static func snapshot(context: ModelContext,
                         now: Date,
                         calendar: Calendar,
                         defaults: UserDefaults) -> AchievementMetrics {
        var metrics = AchievementMetrics()

        let states = (try? context.fetch(FetchDescriptor<ReviewState>())) ?? []
        metrics.learnedWords = states.count
        metrics.masteredWords = states.filter { $0.repetitions >= 3 && $0.intervalDays >= 21 }.count

        let dayKeys = (try? StudyRepository.studiedDayKeys(context: context)) ?? []
        metrics.streak = DayKey.streak(from: dayKeys, today: now, calendar: calendar)

        metrics.clearedDue = defaults.bool(forKey: "flag.clearedDue.v1")
        metrics.importedDeck = defaults.bool(forKey: "flag.importedDeck.v1")
        return metrics
    }
}