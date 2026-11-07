import Foundation

/// 把到期时间说成人话：今天 / 明天 / 3 天后 / 11 月 2 日。
///
/// 全部用 `Calendar` 算整日差，不碰 86400（夏令时、时区改动的坑）。
enum DueText {

    static func relative(to date: Date,
                         now: Date = Date(),
                         calendar: Calendar = .current) -> String {
        let from = calendar.startOfDay(for: now)
        let to = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0

        if days < 0 { return "逾期 \(abs(days)) 天" }
        switch days {
        case 0:  return "今天"
        case 1:  return "明天"
        case 2...7: return "\(days) 天后"
        default:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M 月 d 日"
            return formatter.string(from: date)
        }
    }

    /// 复习间隔文案：1 天 / 3 天 / 2 个月。
    static func interval(_ days: Int) -> String {
        switch days {
        case ..<1:    return "还没安排"
        case 1...30:  return "\(days) 天"
        case 31...364: return "\(days / 30) 个月"
        default:      return "\(days / 365) 年"
        }
    }
}