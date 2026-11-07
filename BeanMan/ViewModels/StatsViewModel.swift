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