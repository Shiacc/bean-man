import Foundation
import SwiftData

// MARK: - 预测模型

/// 未来某一天的到期负载。
///
/// 只回答一个问题：**这一天要复习多少个词**。
/// 新词不参与预测——新词是用户当天的计划，不是「到期」。
struct ForecastDay: Identifiable, Equatable {
    /// `yyyy-MM-dd`
    let dayKey: String
    let date: Date
    /// 距今几天，0 = 今天
    let offset: Int
    /// 落在这一天的到期词数（逾期词压在今天）
    var due: Int
    /// 横轴标签：今天 / 明天 / 11/13
    ///
    /// 生成快照时就按调用方给的日历/时区算好。不能等到显示时再格式化——
    /// 否则测试里传了 `Asia/Shanghai`、设备却在 UTC，同一个 Date 会显示成前一天。
    let label: String

    var id: String { dayKey }
    var isToday: Bool { offset == 0 }
}

/// 未来 N 天的到期预测。
struct ForecastSnapshot: Equatable {
    /// 今天之前就该复习、还没做的词数（这些词已经算进 `days[0]`，别重复相加）
    var overdue: Int = 0
    var days: [ForecastDay] = []

    static let empty = ForecastSnapshot()

    /// 窗口内的到期总数
    var total: Int { days.reduce(0) { $0 + $1.due } }
    var isEmpty: Bool { total == 0 }

    /// 最忙的一天（并列时取更近的一天；全为 0 时返回 nil）
    var peak: ForecastDay? {
        guard var best = days.first else { return nil }
        for day in days.dropFirst() where day.due > best.due {
            best = day
        }
        return best.due > 0 ? best : nil
    }
}

/// 预测的输入：只需要「到期日 + 是否挂起」，不依赖 SwiftData，方便单测。
struct DueEntry: Equatable {
    var dueDate: Date
    var isSuspended: Bool = false
}

// MARK: - 预测

/// 未来 7 天到期预测。
///
/// 口径（与 `StatsService.dueToday` 一致）：
/// - 只算有 `ReviewState` 且未挂起的词；
/// - `dueDate` 当天 00:00 起算进这一天；
/// - 今天之前到期的词全部压到今天（逾期只会让人更该今天动手，不会平摊到未来）；
/// - 超出窗口的到期词直接忽略，不提前借数字。
enum ForecastService {

    static let defaultHorizon = 7

    /// 纯函数：给定到期日集合，算出窗口内每天的负载。
    static func snapshot(entries: [DueEntry],
                         now: Date = Date(),
                         horizon: Int = defaultHorizon,
                         calendar: Calendar = .current) -> ForecastSnapshot {
        let length = max(1, horizon)
        let today = DayKey.startOfDay(now, calendar: calendar)

        var days: [ForecastDay] = []
        var indexByKey: [String: Int] = [:]
        for offset in 0..<length {
            let date = DayKey.adding(days: offset, to: today, calendar: calendar)
            let key = DayKey.string(for: date, calendar: calendar)
            indexByKey[key] = offset
            days.append(ForecastDay(dayKey: key,
                                    date: date,
                                    offset: offset,
                                    due: 0,
                                    label: label(for: date, offset: offset, calendar: calendar)))
        }

        var overdue = 0
        for entry in entries where !entry.isSuspended {
            let dueDay = DayKey.startOfDay(entry.dueDate, calendar: calendar)
            if dueDay < today {
                overdue += 1
                days[0].due += 1
                continue
            }
            let key = DayKey.string(for: dueDay, calendar: calendar)
            guard let index = indexByKey[key] else { continue }
            days[index].due += 1
        }

        return ForecastSnapshot(overdue: overdue, days: days)
    }

    /// 把持久层状态转成纯输入。
    static func entries(from states: [ReviewState]) -> [DueEntry] {
        states.map { DueEntry(dueDate: $0.dueDate, isSuspended: $0.isSuspended) }
    }

    /// 横轴标签；时区/日历跟快照保持一致。
    static func label(for date: Date, offset: Int, calendar: Calendar) -> String {
        switch offset {
        case 0: return "今天"
        case 1: return "明天"
        default:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        }
    }
}