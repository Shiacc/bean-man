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
    var hasAnyDueOrNew: Bool { counts.total > 0 }

    var xiaodouMoment: XiaodouMoment {
        if counts.total == 0 { return .todayDone(streak: streak) }
        if counts.due == 0 && counts.new == 0 { return .todayEmpty }
        return .todayHasWork(due: counts.due, new: counts.new)
    }

    var todayProgress: Double {
        let plan = planTotal
        guard plan > 0 else { return 0 }
        return min(1, Double(counts.learnedToday) / Double(plan))
    }

    /// 今日计划总量 = 今天已学 + 还剩（用于进度条分母）。
    private var planTotal: Int { counts.learnedToday + counts.total }

    func refresh(context: ModelContext) {
        do {
            counts = try StudyRepository.todayCounts(context: context)
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
        } catch {
            counts = TodayCounts()
        }
    }

    /// 今天已经评过的张数（accuracy 的分母）。
    private(set) var answered: Int = 0

    var streakText: String { streak > 0 ? "\(streak) 天" : "—" }
    var accuracyText: String { answered > 0 ? "\(accuracy)%" : "—" }
    var learnedText: String { "\(counts.learnedToday)" }
    var remainText: String { "还剩 \(counts.total) 张卡" }
}