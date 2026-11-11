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

    // MARK: - 掌握度三段环

    /// 三段：未学 / 学习中 / 已掌握（PRD §5.8）。顺序就是图例顺序。
    var masterySegments: [MasterySegment] {
        [
            MasterySegment(kind: .untouched, value: snapshot.untouchedWords),
            MasterySegment(kind: .learning, value: snapshot.learningWords),
            MasterySegment(kind: .mastered, value: snapshot.masteredWords)
        ]
    }

    /// 环只画有值的段：0 值扇区在 Chart 里没有意义，还会留一道缝。
    var visibleMasterySegments: [MasterySegment] {
        masterySegments.filter { $0.value > 0 }
    }

    var hasMasteryData: Bool { snapshot.totalWords > 0 }

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

// MARK: - 掌握度段

/// 掌握度环的一段。颜色留在视图层，这里只负责「叫什么、多少」。
struct MasterySegment: Identifiable, Equatable {

    enum Kind: String {
        case untouched
        case learning
        case mastered

        var label: String {
            switch self {
            case .untouched: return "未学"
            case .learning: return "学习中"
            case .mastered: return "已掌握"
            }
        }
    }

    let kind: Kind
    let value: Int

    var id: String { kind.rawValue }
    var label: String { kind.label }
}