import Foundation
import SwiftData

/// 队列里的一张卡。`isNew` 决定评分时是否新建 ReviewState。
struct QueueItem: Identifiable, Equatable {
    let id: UUID          // 直接用 word.id，做 ForEach 的稳定 id
    let word: Word
    let isNew: Bool
    /// 小豆额外推进来的重点词：不受每日新词/复习额度限制，但中考勤。
    var isRecommended: Bool = false

    static func == (lhs: QueueItem, rhs: QueueItem) -> Bool {
        lhs.id == rhs.id && lhs.isNew == rhs.isNew && lhs.isRecommended == rhs.isRecommended
    }
}

/// 今日任务的数字。
struct TodayCounts: Equatable {
    var due: Int = 0          // 还剩多少到期词
    var new: Int = 0          // 还能学多少新词
    var learnedToday: Int = 0 // 今天已经评过多少张
    var recommended: Int = 0  // 小豆额外推进来的重点词
    var total: Int { due + new + recommended }
}

/// 所有涉及 SwiftData 查询的地方都集中在这里：
/// - View / ViewModel 不再自己写 FetchDescriptor，方便单元测试（用内存容器）。
/// - 队列规则（复习在前、新词在后、各自限额）只有一份实现。
enum StudyRepository {

    // MARK: - 当前词库

    static func currentDeck(context: ModelContext) throws -> Deck? {
        let decks = try context.fetch(FetchDescriptor<Deck>(sortBy: [SortDescriptor(\.sortIndex)]))
        guard !decks.isEmpty else { return nil }
        let settings = try AppSettingsStore.settings(in: context)
        if let id = settings?.selectedDeckID, let matched = decks.first(where: { $0.id == id }) {
            return matched
        }
        return decks.first(where: { $0.isBuiltIn }) ?? decks.first
    }

    // MARK: - 今日队列

    /// 生成今日学习队列：到期的复习词在前，新词在后，各自按剩余额度截断；
    /// 最后追加小豆推荐的错词（最多 3 个，不占额度）。
    static func buildQueue(context: ModelContext,
                           now: Date = Date(),
                           calendar: Calendar = .current,
                           newLimitOverride: Int? = nil,
                           includeRecommended: Bool = true) throws -> [QueueItem] {

        guard let deck = try currentDeck(context: context) else { return [] }
        let settings = try AppSettingsStore.settings(in: context)
        let configuredNewLimit = settings?.dailyNewLimit ?? 20
        let newLimit = newLimitOverride ?? configuredNewLimit
        let reviewLimit = settings?.dailyReviewLimit ?? 100

        let deckID = deck.id
        let words = try context.fetch(
            FetchDescriptor<Word>(predicate: #Predicate<Word> { $0.deckID == deckID })
        )
        let states = try context.fetch(
            FetchDescriptor<ReviewState>(predicate: #Predicate<ReviewState> { $0.deckID == deckID })
        )
        let records = try context.fetch(
            FetchDescriptor<StudyRecord>(predicate: #Predicate<StudyRecord> { $0.deckID == deckID })
        )

        let startOfToday = calendar.startOfDay(for: now)

        // 今天已经用掉多少额度
        let todaysRecords = records.filter { $0.reviewedAt >= startOfToday }
        let newUsedToday = todaysRecords.filter { $0.wasNew }.count
        let reviewDoneToday = todaysRecords.filter { !$0.wasNew }.count

        let reviewQuota = max(0, reviewLimit - reviewDoneToday)
        let newQuota = max(0, newLimit - newUsedToday)

        var stateByWord: [UUID: ReviewState] = [:]
        for state in states { stateByWord[state.wordID] = state }

        // 到期复习：dueDate <= 今天 00:00 且未挂起
        let dueStates = states
            .filter { !$0.isSuspended && $0.dueDate <= startOfToday }
            .sorted {
                if $0.dueDate != $1.dueDate { return $0.dueDate < $1.dueDate }
                return $0.lapses > $1.lapses
            }

        let wordByID = Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })
        var dueItems: [QueueItem] = []
        for state in dueStates {
            guard dueItems.count < reviewQuota else { break }
            guard let word = wordByID[state.wordID] else { continue }
            dueItems.append(QueueItem(id: word.id, word: word, isNew: false))
        }

        // 新词：还没有 ReviewState 的词，按 sortIndex 顺序
        let newWords = words
            .filter { stateByWord[$0.id] == nil }
            .sorted { $0.sortIndex < $1.sortIndex }

        var newItems: [QueueItem] = []
        for word in newWords {
            guard newItems.count < newQuota else { break }
            newItems.append(QueueItem(id: word.id, word: word, isNew: true))
        }

        // 小豆推荐：错得多、又不是今天到期的词。只补充，不顶替任何额度。
        var recommended: [QueueItem] = []
        if includeRecommended {
            let queuedIDs = Set(dueItems.map(\.id)).union(newItems.map(\.id))
            let dueIDs = Set(dueStates.map(\.wordID))
            let picked = states
                .filter { !$0.isSuspended && !$0.isWrongBookHidden }
                .filter { $0.lapses > 0 && !dueIDs.contains($0.wordID) && !queuedIDs.contains($0.wordID) }
                .sorted { lhs, rhs in
                    if lhs.lapses != rhs.lapses { return lhs.lapses > rhs.lapses }
                    return lhs.dueDate < rhs.dueDate
                }
                .prefix(3)

            for state in picked {
                guard let word = wordByID[state.wordID] else { continue }
                recommended.append(QueueItem(id: word.id,
                                             word: word,
                                             isNew: false,
                                             isRecommended: true))
            }
        }

        return dueItems + newItems + recommended
    }

    /// 只算数字，不建队列（今日页用，避免把整库词都读进内存）。
    static func todayCounts(context: ModelContext,
                            now: Date = Date(),
                            calendar: Calendar = .current,
                            newLimitOverride: Int? = nil,
                            includeRecommended: Bool = true) throws -> TodayCounts {

        guard let deck = try currentDeck(context: context) else { return TodayCounts() }
        let settings = try AppSettingsStore.settings(in: context)
        let configuredNewLimit = settings?.dailyNewLimit ?? 20
        let newLimit = newLimitOverride ?? configuredNewLimit
        let reviewLimit = settings?.dailyReviewLimit ?? 100

        let deckID = deck.id
        let words = try context.fetch(
            FetchDescriptor<Word>(predicate: #Predicate<Word> { $0.deckID == deckID })
        )
        let states = try context.fetch(
            FetchDescriptor<ReviewState>(predicate: #Predicate<ReviewState> { $0.deckID == deckID })
        )
        let records = try context.fetch(
            FetchDescriptor<StudyRecord>(predicate: #Predicate<StudyRecord> { $0.deckID == deckID })
        )

        let startOfToday = calendar.startOfDay(for: now)
        let todaysRecords = records.filter { $0.reviewedAt >= startOfToday }
        let newUsedToday = todaysRecords.filter { $0.wasNew }.count
        let reviewDoneToday = todaysRecords.filter { !$0.wasNew }.count

        let dueCount = states.filter { !$0.isSuspended && $0.dueDate <= startOfToday }.count
        let learnedWordIDs = Set(states.map { $0.wordID })
        let newAvailable = words.filter { !learnedWordIDs.contains($0.id) }.count

        let dueQuota = max(0, reviewLimit - reviewDoneToday)
        let newQuota = max(0, newLimit - newUsedToday)

        // 推荐词：错得多、今天又不到期，且不在今天的到期/新词配额里
        var recommendedCount = 0
        if includeRecommended {
            let dueIDs = Set(states.filter { !$0.isSuspended && $0.dueDate <= startOfToday }.map(\.wordID))
            let newIDs = Set(words.filter { !learnedWordIDs.contains($0.id) }.map(\.id))
            recommendedCount = min(3, states.filter {
                !$0.isSuspended && !$0.isWrongBookHidden && $0.lapses > 0
                    && !dueIDs.contains($0.wordID) && !newIDs.contains($0.wordID)
            }.count)
        }

        return TodayCounts(due: min(dueCount, dueQuota),
                           new: min(newAvailable, newQuota),
                           learnedToday: todaysRecords.count,
                           recommended: recommendedCount)
    }

    // MARK: - 评分写回

    /// 应用一次评分：更新 ReviewState、写入 StudyRecord、累加会话计数。
    @discardableResult
    static func apply(rating: Rating,
                      to item: QueueItem,
                      context: ModelContext,
                      session: StudySession? = nil,
                      now: Date = Date(),
                      calendar: Calendar = .current) throws -> SRSOutcome {

        let word = item.word
        let state = word.reviewState

        let previousDue = state?.dueDate
        let previousInterval = state?.intervalDays ?? 0

        let outcome = SRSAlgorithm.schedule(easeFactor: state?.easeFactor ?? 2.5,
                                            intervalDays: state?.intervalDays ?? 0,
                                            repetitions: state?.repetitions ?? 0,
                                            lapses: state?.lapses ?? 0,
                                            rating: rating,
                                            now: now,
                                            calendar: calendar)

        let target: ReviewState
        if let existing = state {
            target = existing
        } else {
            let created = ReviewState(wordID: word.id,
                                      deckID: word.deckID,
                                      dueDate: outcome.dueDate)
            created.word = word
            word.reviewState = created
            context.insert(created)
            target = created
        }

        target.easeFactor = outcome.easeFactor
        target.intervalDays = outcome.intervalDays
        target.repetitions = outcome.repetitions
        target.dueDate = outcome.dueDate
        target.lapses = outcome.lapses
        target.phase = outcome.phase
        target.lastReviewedAt = now
        target.lastRatingRaw = rating.rawValue

        // 又被判成「不认识 / 模糊」：如果是用户手动移出错词本的，自动放回去。
        if rating.needsReviewList {
            target.wrongBookHiddenAt = nil
        }

        let record = StudyRecord(wordID: word.id,
                                 deckID: word.deckID,
                                 rating: rating,
                                 wasNew: item.isNew,
                                 reviewedAt: now,
                                 previousDueDate: previousDue,
                                 newDueDate: outcome.dueDate,
                                 previousIntervalDays: previousInterval,
                                 newIntervalDays: outcome.intervalDays,
                                 durationMs: 0)
        record.word = word
        record.session = session
        context.insert(record)

        if let session {
            session.answeredCount += 1
            if item.isNew { session.newWordCount += 1 } else { session.reviewCount += 1 }
            if rating.isCorrect { session.correctCount += 1 }
        }

        try context.save()
        return outcome
    }

    // MARK: - 打卡

    /// 历史打卡日集合（所有会话的 dayKey）。
    static func studiedDayKeys(context: ModelContext) throws -> Set<String> {
        let sessions = try context.fetch(FetchDescriptor<StudySession>())
        return Set(sessions.map { $0.dayKey })
    }
}