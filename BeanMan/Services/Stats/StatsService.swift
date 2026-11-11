import Foundation
import SwiftData

/// 某一天的学习量。
struct DayStat: Identifiable, Equatable {
    /// yyyy-MM-dd
    let dayKey: String
    let date: Date
    let newWords: Int
    let reviews: Int

    var total: Int { newWords + reviews }
    var id: String { dayKey }

    /// 柱状图横轴：周几
    var weekdayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    /// 「11/7」
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

/// 统计页要的全部数字。
struct StatsSnapshot: Equatable {
    var streak: Int = 0
    var learnedToday: Int = 0
    var dueToday: Int = 0
    var totalWords: Int = 0
    var learnedWords: Int = 0
    var masteredWords: Int = 0
    var accuracy: Double = 0
    var reviewedTotal: Int = 0
    var last7Days: [DayStat] = []
    /// 未来 7 天到期预测（统计页「到期曲线」）
    var forecast: ForecastSnapshot = .empty

    static let empty = StatsSnapshot()

    var accuracyText: String { "\(Int((accuracy * 100).rounded()))%" }

    var masteredProgress: Double {
        totalWords == 0 ? 0 : Double(masteredWords) / Double(totalWords)
    }

    var weekTotal: Int { last7Days.reduce(0) { $0 + $1.total } }
}

/// 统计口径都在这里，界面只负责画。
///
/// 刻意不建额外的统计表：所有数字都从 `StudySession` / `ReviewState` 现算，
/// 词库一删，统计自动跟着变，不会出现「删了词库但统计还在」的脏数据。
enum StatsService {

    static func snapshot(context: ModelContext,
                         now: Date = Date(),
                         calendar: Calendar = .current,
                         deck: Deck? = nil) throws -> StatsSnapshot {
        let today = DayKey.startOfDay(now, calendar: calendar)
        let settings = try? AppSettingsStore.current(in: context)
        let decks = try context.fetch(FetchDescriptor<Deck>())
        let currentDeck = deck ?? decks.first { $0.id == settings?.selectedDeckID } ?? decks.first

        var snapshot = StatsSnapshot()
        let words = currentDeck?.words ?? []
        snapshot.totalWords = words.count

        var due = 0
        var learned = 0
        var mastered = 0
        for word in words {
            guard let state = word.reviewState else { continue }
            learned += 1
            if !state.isSuspended && state.dueDate <= today { due += 1 }
            if state.repetitions >= 3 && state.intervalDays >= 21 { mastered += 1 }
        }
        snapshot.dueToday = due
        snapshot.learnedWords = learned
        snapshot.masteredWords = mastered

        // 未来 7 天到期：逾期词压到今天，和 dueToday 的口径一致
        snapshot.forecast = ForecastService.snapshot(
            entries: ForecastService.entries(from: words.compactMap(\.reviewState)),
            now: now,
            calendar: calendar)

        // 只算当前词库的会话
        let allSessions = try context.fetch(FetchDescriptor<StudySession>(sortBy: [SortDescriptor(\.startedAt)]))
        let sessions = allSessions.filter { session in
            guard let currentDeck else { return true }
            return session.records.contains { $0.deckID == currentDeck.id } || session.records.isEmpty
        }

        let answered = sessions.reduce(0) { $0 + $1.answeredCount }
        let correct = sessions.reduce(0) { $0 + $1.correctCount }
        snapshot.reviewedTotal = answered
        snapshot.accuracy = answered == 0 ? 0 : Double(correct) / Double(answered)

        let todayKey = DayKey.string(for: today, calendar: calendar)
        snapshot.learnedToday = sessions
            .filter { $0.dayKey == todayKey }
            .reduce(0) { $0 + $1.newWordCount + $1.reviewCount }

        snapshot.streak = DayKey.streak(from: Set(sessions.map(\.dayKey)), today: now, calendar: calendar)

        // 最近 7 天（含今天），没有记录的补 0
        var byDay: [String: (new: Int, review: Int)] = [:]
        for session in sessions {
            var entry = byDay[session.dayKey] ?? (0, 0)
            entry.new += session.newWordCount
            entry.review += session.reviewCount
            byDay[session.dayKey] = entry
        }

        var days: [DayStat] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            let date = DayKey.adding(days: -offset, to: today, calendar: calendar)
            let key = DayKey.string(for: date, calendar: calendar)
            let entry = byDay[key] ?? (0, 0)
            days.append(DayStat(dayKey: key, date: date, newWords: entry.new, reviews: entry.review))
        }
        snapshot.last7Days = days

        return snapshot
    }
}