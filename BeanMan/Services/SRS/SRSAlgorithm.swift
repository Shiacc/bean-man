import Foundation

/// 一次调度计算的结果。纯值类型，不依赖 SwiftData，方便单测。
struct SRSOutcome: Equatable {
    var easeFactor: Double
    var intervalDays: Int
    var repetitions: Int
    var dueDate: Date
    var lapses: Int
    var phase: StudyPhase

    /// 与旧状态相比间隔是否变长了，用于界面提示「下次 7 天后」。
    var isGrowth: Bool { intervalDays > 1 }
}

/// 简化版 SM-2。
///
/// 设计取舍（见 Docs/01-阶段1）：
/// - 只保留四个评分档位，公式全部写成纯函数，不碰 SwiftData。
/// - 天数一律用 Calendar 计算，`dueDate = 今天 00:00 + intervalDays 天`。
/// - 所有输出都夹在安全区间内：ease ∈ [1.3, 3.0]，interval ∈ [1, 365]。
enum SRSAlgorithm {

    static let minEase = 1.3
    static let maxEase = 3.0
    static let maxInterval = 365

    /// 计算下一次复习安排。
    ///
    /// - Parameters:
    ///   - easeFactor: 当前 ease（新词传 2.5）
    ///   - intervalDays: 当前间隔（新词传 0）
    ///   - repetitions: 当前连续答对次数
    ///   - lapses: 当前遗忘次数
    ///   - rating: 用户反馈
    static func schedule(easeFactor: Double,
                         intervalDays: Int,
                         repetitions: Int,
                         lapses: Int,
                         rating: Rating,
                         now: Date = Date(),
                         calendar: Calendar = .current) -> SRSOutcome {

        var ease = easeFactor
        var interval = intervalDays
        var reps = repetitions
        var lapses = lapses
        var phase: StudyPhase = .review

        switch rating {
        case .again:
            // 重新开始：明天再来一次
            reps = 0
            interval = 1
            ease = max(minEase, ease - 0.20)
            lapses += 1
            phase = .relearning

        case .hard:
            reps += 1
            if interval <= 0 { interval = 1 }
            else if interval == 1 { interval = 2 }
            else { interval = max(interval + 1, Int((Double(interval) * 1.2).rounded())) }
            ease = max(minEase, ease - 0.15)
            phase = reps >= 2 ? .review : .learning

        case .good:
            reps += 1
            if interval <= 0 { interval = 1 }
            else if interval == 1 { interval = 3 }
            else { interval = Int((Double(interval) * ease).rounded()) }
            phase = reps >= 2 ? .review : .learning

        case .easy:
            reps += 1
            if interval <= 0 { interval = 4 }
            else if interval == 1 { interval = 7 }
            else { interval = Int((Double(interval) * ease * 1.3).rounded()) }
            ease = min(maxEase, ease + 0.15)
            phase = reps >= 2 ? .review : .learning
        }

        interval = min(maxInterval, max(1, interval))
        ease = min(maxEase, max(minEase, ease))

        // 到期日永远是本地时区的 00:00，避免「差几小时今天不算到期」的坑
        let base = calendar.startOfDay(for: now)
        let due = calendar.date(byAdding: .day, value: interval, to: base) ?? base

        return SRSOutcome(easeFactor: ease,
                          intervalDays: interval,
                          repetitions: reps,
                          dueDate: due,
                          lapses: lapses,
                          phase: phase)
    }
}