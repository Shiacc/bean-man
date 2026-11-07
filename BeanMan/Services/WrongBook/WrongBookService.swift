import Foundation
import SwiftData

// MARK: - 错词条目

/// 错词本里的一行。
///
/// 错词本不是一张表：它由 `ReviewState` 的 `lapses` / `lastRatingRaw` 派生出来
/// （PRD §5.6），所以这里只是「算好的一个视图」。
struct WrongWordEntry: Identifiable, Equatable {
    let word: Word
    /// 累计「不认识」的次数（`ReviewState.lapses`）。
    let wrongCount: Int
    /// 最近一次评分。
    let lastRating: Rating?
    let lastReviewedAt: Date?
    let dueDate: Date
    /// 用户手动移出过。
    let isHidden: Bool
    /// 现在是否到期（由 snapshot 时刻算好，避免列表里反复算）。
    let isDue: Bool

    /// 用 word.id 做 ForEach 的稳定 id。
    var id: UUID { word.id }

    /// 「错了 3 次」/「上次标记为模糊」。
    var reasonText: String {
        if wrongCount > 0 {
            return "错了 \(wrongCount) 次"
        }
        if let lastRating {
            return "上次：\(lastRating.title)"
        }
        return "手动加入"
    }

    static func == (lhs: WrongWordEntry, rhs: WrongWordEntry) -> Bool {
        lhs.id == rhs.id
            && lhs.isHidden == rhs.isHidden
            && lhs.wrongCount == rhs.wrongCount
            && lhs.isDue == rhs.isDue
    }
}

/// 错词本的快照。一次查询算完所有数字，View 不再自己 fetch。
struct WrongBookSnapshot {
    var entries: [WrongWordEntry] = []

    /// 没被移出、也不挂起的错词数量（就是界面上「错词本 N 个」）。
    var visibleCount: Int { entries.filter { !$0.isHidden }.count }
    /// 其中已经到期待复习的。
    var dueCount: Int { entries.filter { !$0.isHidden && $0.isDue }.count }
    /// 被手动移出的。
    var hiddenCount: Int { entries.filter { $0.isHidden }.count }
    /// 全部记录（含已移出）。
    var totalCount: Int { entries.count }

    static let empty = WrongBookSnapshot()
}

// MARK: - 错词本查询

/// 错词本的全部读写都走这里。
///
/// 三条约束：
/// - 只认当前词库（多词库混合学习是后续版本的事）。
/// - 派生规则只有一份：`ReviewState.isWrongWord`。
/// - 排序只有一份：到期在前、错得多的在前。
enum WrongBookService {

    /// 生成快照。
    static func snapshot(context: ModelContext,
                         now: Date = Date(),
                         calendar: Calendar = .current) throws -> WrongBookSnapshot {

        guard let deck = try StudyRepository.currentDeck(context: context) else {
            return .empty
        }

        let deckID = deck.id
        let words = try context.fetch(
            FetchDescriptor<Word>(predicate: #Predicate<Word> { $0.deckID == deckID })
        )
        let states = try context.fetch(
            FetchDescriptor<ReviewState>(predicate: #Predicate<ReviewState> { $0.deckID == deckID })
        )

        let wordByID = Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })
        let startOfToday = calendar.startOfDay(for: now)

        var entries: [WrongWordEntry] = []
        for state in states where state.isWrongWord {
            guard let word = wordByID[state.wordID] else { continue }
            entries.append(WrongWordEntry(word: word,
                                          wrongCount: state.lapses,
                                          lastRating: state.lastRating,
                                          lastReviewedAt: state.lastReviewedAt,
                                          dueDate: state.dueDate,
                                          isHidden: state.isWrongBookHidden,
                                          isDue: state.dueDate <= startOfToday))
        }

        entries.sort { lhs, rhs in
            // 移出的沉到最后
            if lhs.isHidden != rhs.isHidden { return !lhs.isHidden }
            // 到期的在前
            if lhs.isDue != rhs.isDue { return lhs.isDue }
            // 错得多的在前
            if lhs.wrongCount != rhs.wrongCount { return lhs.wrongCount > rhs.wrongCount }
            // 同样条件，早就到期的在前
            return lhs.dueDate < rhs.dueDate
        }

        return WrongBookSnapshot(entries: entries)
    }

    /// 错词数量（今日页的入口角标用，不建列表）。
    static func visibleCount(context: ModelContext,
                             now: Date = Date(),
                             calendar: Calendar = .current) throws -> Int {
        try snapshot(context: context, now: now, calendar: calendar).visibleCount
    }

    /// 从错词本发起专项复习的队列。
    ///
    /// 只取没被移出的；到期的排前面，其次按错误次数。
    /// 和今日队列不同，这里**不受每日限额约束**——用户主动点的复习不该被挡。
    static func reviewQueue(context: ModelContext,
                            limit: Int = 20,
                            now: Date = Date(),
                            calendar: Calendar = .current) throws -> [QueueItem] {

        guard limit > 0 else { return [] }
        let all = try snapshot(context: context, now: now, calendar: calendar)
            .entries
            .filter { !$0.isHidden }

        let ordered = all.sorted { lhs, rhs in
            if lhs.isDue != rhs.isDue { return lhs.isDue }
            if lhs.wrongCount != rhs.wrongCount { return lhs.wrongCount > rhs.wrongCount }
            return lhs.dueDate < rhs.dueDate
        }

        return ordered.prefix(limit).map {
            QueueItem(id: $0.word.id, word: $0.word, isNew: false)
        }
    }

    // MARK: - 手动移出 / 恢复

    /// 把词移出错词本（只改一个时间戳，不动记忆曲线）。
    @discardableResult
    static func hide(_ word: Word, context: ModelContext, now: Date = Date()) throws -> Bool {
        guard let state = word.reviewState else { return false }
        state.wrongBookHiddenAt = now
        try context.save()
        return true
    }

    /// 恢复回错词本。
    static func restore(_ word: Word, context: ModelContext) throws {
        guard let state = word.reviewState else { return }
        state.wrongBookHiddenAt = nil
        try context.save()
    }
}