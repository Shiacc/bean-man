import Foundation
import Observation
import SwiftData

/// 今日页的状态。只负责「取数字 + 组织展示」，不碰任何 SwiftUI 类型。
@MainActor
@Observable
final class TodayViewModel {

    var counts = TodayCounts()
    var streak: Int = 0
    var accuracy: Int = 0          // 0...100，今天为止
    var deckName: String = ""
    var totalWordCount: Int = 0
    /// 已经学过（有复习状态）的词数 —— 测试页至少要 4 个才出得了题。
    var learnedWordCount: Int = 0
    /// 错词本里还有多少个词（今日页入口角标）。
    var wrongCount: Int = 0
    /// 生词本里收藏了多少个词。
    var favoriteCount: Int = 0
    /// 小豆的分析结果（洞察 + 推荐词）
    var insight = InsightSnapshot.empty

    /// 「知道了」的冷却与每日条数
    private let insightCenter = InsightCenter.shared

    /// 真正该展示的洞察（dismiss 冷却 + 每天最多 3 条）
    var visibleInsights: [Insight] {
        insightCenter.visible(insight.insights)
    }

    /// 今日页小豆卡只展示最高优先级的那一条
    var headlineInsight: Insight? { visibleInsights.first }

    func dismiss(_ insight: Insight) {
        insightCenter.dismiss(insight.kind)
    }

    var hasAnyDueOrNew: Bool { counts.total > 0 }
    var hasRecommendations: Bool { !insight.recommendations.isEmpty }

    var xiaodouMoment: XiaodouMoment {
        if counts.total == 0 { return .todayDone(streak: streak) }
        if counts.due == 0 && counts.new == 0 { return .todayEmpty }
        return .todayHasWork(due: counts.due, new: counts.new)
    }

    /// 小豆的表情：有活干是常态，今天已经干完就开心，压根没词可学就打瞌睡。
    var xiaodouExpression: AnimalExpression {
        if counts.total > 0 { return .normal }
        if counts.learnedToday > 0 { return .happy }
        return .sleepy
    }

    var todayProgress: Double {
        let plan = planTotal
        guard plan > 0 else { return 0 }
        return min(1, Double(counts.learnedToday) / Double(plan))
    }

    /// 今日计划总量 = 今天已学 + 还剩（用于进度条分母）。
    private var planTotal: Int { counts.learnedToday + counts.total }

    func refresh(context: ModelContext) {
        let isPro = PurchaseService.shared.isPro
        let configuredNewLimit = (try? AppSettingsStore.settings(in: context))?.dailyNewLimit ?? 20
        let newLimit = TierGate.maxDailyNew(isPro: isPro, requested: configuredNewLimit)

        do {
            counts = try StudyRepository.todayCounts(context: context, newLimitOverride: newLimit)
            deckName = (try StudyRepository.currentDeck(context: context)?.name) ?? "还没有词库"

            let startOfToday = DayKey.startOfDay(Date())
            let records = try context.fetch(FetchDescriptor<StudyRecord>())
            let todays = records.filter { $0.reviewedAt >= startOfToday }
            let correct = todays.filter { $0.rating.isCorrect }.count
            answered = todays.count
            accuracy = answered == 0 ? 0 : Int((Double(correct) / Double(answered) * 100).rounded())

            streak = DayKey.streak(from: try StudyRepository.studiedDayKeys(context: context))

            let words = try context.fetch(FetchDescriptor<Word>())
            totalWordCount = words.count
            learnedWordCount = words.filter { $0.reviewState != nil }.count
            favoriteCount = words.filter(\.isFavorite).count

            wrongCount = try WrongBookService.visibleCount(context: context)

            insight = (try? InsightEngine.snapshot(context: context)) ?? .empty

            // 当天到期词清零、且今天确实学过 → 解锁「清空到期」
            if counts.due == 0 && counts.learnedToday > 0 {
                AchievementCenter.shared.markClearedDue()
            }
            AchievementCenter.shared.check(context: context)
        } catch {
            counts = TodayCounts()
            insight = .empty
        }
    }

    /// 今天已经评过的张数（accuracy 的分母）。
    private(set) var answered: Int = 0

    /// 免费版被额度卡住时，今日页要提示一句。
    var dailyNewLimitNote: String? {
        guard !PurchaseService.shared.isPro else { return nil }
        let configured = 20
        return "免费版每天最多 \(TierGate.maxDailyNew(isPro: false, requested: configured)) 个新词"
    }

    var streakText: String { streak > 0 ? "\(streak) 天" : "—" }
    var accuracyText: String { answered > 0 ? "\(accuracy)%" : "—" }
    var learnedText: String { "\(counts.learnedToday)" }
    var remainText: String { "还剩 \(counts.total) 张卡" }
}