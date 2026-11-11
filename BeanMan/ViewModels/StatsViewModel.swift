import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class StatsViewModel {

    private(set) var snapshot: StatsSnapshot = .empty
    private(set) var errorMessage: String?

    var streakText: String { "\(snapshot.streak)" }
    var hasAnyHistory: Bool { snapshot.reviewedTotal > 0 || snapshot.learnedWords > 0 }
    var weekTotalText: String { "\(snapshot.weekTotal)" }

    var masteryText: String {
        "\(Int((snapshot.masteredProgress * 100).rounded()))%"
    }

    // MARK: - 到期预测

    var hasForecast: Bool { !snapshot.forecast.isEmpty }

    var forecastTotalText: String { "\(snapshot.forecast.total)" }

    /// 曲线下面那一句：先说逾期（最该动手的事），再说最忙的一天。
    var forecastNote: String {
        let forecast = snapshot.forecast
        if forecast.isEmpty {
            return "未来 7 天没有到期词，先按自己的节奏学新词"
        }
        if forecast.overdue > 0 {
            return "其中 \(forecast.overdue) 个已经逾期，会一直压在今天"
        }
        if let peak = forecast.peak {
            if peak.offset == 0 {
                return "最忙就是今天：\(peak.due) 个词到期"
            }
            return "最忙的是\(peak.label)：\(peak.due) 个词到期"
        }
        return "按现在的节奏，一周还算轻松"
    }

    var xiaodouMoment: XiaodouMoment {
        if snapshot.streak >= 7 {
            return .todayDone(streak: snapshot.streak)
        }
        if snapshot.dueToday > 0 {
            return .todayHasWork(due: snapshot.dueToday, new: 0)
        }
        return .todayEmpty
    }

    func refresh(context: ModelContext) {
        do {
            snapshot = try StatsService.snapshot(context: context)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}