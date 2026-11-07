import Foundation

/// 统一的日期工具。
///
/// 设计约定（见 Docs/01-阶段1）：所有「哪一天」的判断都走本地日历，
/// 绝不使用 `date.timeIntervalSince1970 / 86400` 这类硬算，避免夏令时与时区漂移。
/// 打卡、柱状图、今日额度都基于 `dayKey` 字符串（yyyy-MM-dd）做集合运算。
enum DayKey {

    /// 生成 `yyyy-MM-dd` 字符串（本地时区）。
    static func string(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d",
                      comps.year ?? 1970, comps.month ?? 1, comps.day ?? 1)
    }

    /// 某个时刻所在日期的 00:00。
    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    /// 在 `date` 上加减天数，保持本地日历语义。
    static func adding(days: Int, to date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// 把 `yyyy-MM-dd` 解析回当天 00:00，用于连续打卡的相邻判断。
    static func date(from key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var comps = DateComponents()
        comps.year = parts[0]
        comps.month = parts[1]
        comps.day = parts[2]
        return calendar.date(from: comps)
    }

    /// 连续打卡天数：从今天（或指定的基准日）往前数，遇到缺口就停。
    ///
    /// - 今天没学不算断：只要昨天有记录，连续天数仍然保留（体验上更宽容）。
    static func streak(from dayKeys: Set<String>, today: Date = Date(), calendar: Calendar = .current) -> Int {
        guard !dayKeys.isEmpty else { return 0 }
        var cursor = startOfDay(today, calendar: calendar)
        // 如果今天还没有记录，从昨天开始数
        if !dayKeys.contains(string(for: cursor, calendar: calendar)) {
            cursor = adding(days: -1, to: cursor, calendar: calendar)
        }
        var count = 0
        while dayKeys.contains(string(for: cursor, calendar: calendar)) {
            count += 1
            cursor = adding(days: -1, to: cursor, calendar: calendar)
        }
        return count
    }
}