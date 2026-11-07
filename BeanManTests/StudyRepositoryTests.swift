import XCTest
import SwiftData
@testable import BeanMan

@MainActor
final class StudyRepositoryTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        container = BeanManStore.makeContainer(inMemory: true)
        context = ModelContext(container)
        BeanManStore.bootstrap(context)
    }

    private func words() throws -> [Word] {
        try context.fetch(FetchDescriptor<Word>(sortBy: [SortDescriptor(\.sortIndex)]))
    }

    // MARK: - 队列

    func testNewWordQueueRespectsDailyLimit() throws {
        let settings = try AppSettingsStore.current(in: context)
        settings.dailyNewLimit = 10
        try context.save()

        let queue = try StudyRepository.buildQueue(context: context)
        XCTAssertEqual(queue.count, 10)
        XCTAssertTrue(queue.allSatisfy { $0.isNew })
    }

    func testDueReviewsComeFirstAndAreSorted() throws {
        let all = try words()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // 让第 5、9 个词变成「昨天到期」
        for (index, word) in all.enumerated() where index == 5 || index == 9 {
            let state = ReviewState(wordID: word.id, deckID: word.deckID,
                                    easeFactor: 2.5, intervalDays: 3, repetitions: 2,
                                    dueDate: index == 5 ? yesterday : today,
                                    phase: .review)
            state.word = word
            word.reviewState = state
            context.insert(state)
        }
        try context.save()

        let settings = try AppSettingsStore.current(in: context)
        settings.dailyNewLimit = 3
        settings.dailyReviewLimit = 10
        try context.save()

        let queue = try StudyRepository.buildQueue(context: context)
        XCTAssertEqual(queue.count, 5)                       // 2 复习 + 3 新词
        XCTAssertFalse(queue[0].isNew)
        XCTAssertFalse(queue[1].isNew)
        XCTAssertTrue(queue[2].isNew)

        // 到期更早的排前面
        XCTAssertEqual(queue[0].word.id, all[5].id)
    }

    func testReviewLimitCountsTodayWork() throws {
        let all = try words().prefix(6)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for word in all {
            let state = ReviewState(wordID: word.id, deckID: word.deckID,
                                    easeFactor: 2.5, intervalDays: 2, repetitions: 2,
                                    dueDate: today, phase: .review)
            state.word = word
            word.reviewState = state
            context.insert(state)
        }
        try context.save()

        let settings = try AppSettingsStore.current(in: context)
        settings.dailyReviewLimit = 4
        settings.dailyNewLimit = 0
        try context.save()

        let queue = try StudyRepository.buildQueue(context: context)
        XCTAssertEqual(queue.count, 4)
    }

    // MARK: - 评分写回

    func testRatingCreatesReviewStateAndRecord() throws {
        let item = try XCTUnwrap(try StudyRepository.buildQueue(context: context).first)
        XCTAssertTrue(item.isNew)
        XCTAssertNil(item.word.reviewState)

        let outcome = try StudyRepository.apply(rating: .good, to: item, context: context)

        XCTAssertNotNil(item.word.reviewState)
        XCTAssertEqual(item.word.reviewState?.intervalDays, outcome.intervalDays)
        XCTAssertEqual(item.word.reviewState?.repetitions, 1)

        let records = try context.fetch(FetchDescriptor<StudyRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.wasNew, true)
        XCTAssertEqual(records.first?.rating, .good)
    }

    func testSecondRatingKeepsOneStatePerWord() throws {
        let item = try XCTUnwrap(try StudyRepository.buildQueue(context: context).first)
        try StudyRepository.apply(rating: .again, to: item, context: context)

        let refreshed = QueueItem(id: item.word.id, word: item.word, isNew: false)
        try StudyRepository.apply(rating: .good, to: refreshed, context: context)

        let states = try context.fetch(FetchDescriptor<ReviewState>())
        XCTAssertEqual(states.filter { $0.wordID == item.word.id }.count, 1)
    }

    // MARK: - 今日额度

    func testTodayCountsShrinkAfterRating() throws {
        let settings = try AppSettingsStore.current(in: context)
        settings.dailyNewLimit = 5
        try context.save()

        let before = try StudyRepository.todayCounts(context: context)
        XCTAssertEqual(before.new, 5)

        let queue = try StudyRepository.buildQueue(context: context)
        try StudyRepository.apply(rating: .good, to: queue[0], context: context)

        let after = try StudyRepository.todayCounts(context: context)
        XCTAssertEqual(after.new, 4)
        XCTAssertEqual(after.learnedToday, 1)
    }

    // MARK: - 打卡

    func testStreakCountsConsecutiveDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var keys: Set<String> = []
        for offset in 0..<3 {
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            keys.insert(DayKey.string(for: day, calendar: calendar))
        }
        XCTAssertEqual(DayKey.streak(from: keys, today: today, calendar: calendar), 3)
    }

    func testStreakStopsAtGap() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var keys: Set<String> = []
        for offset in [0, 1, 3] {                       // 缺第 2 天
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            keys.insert(DayKey.string(for: day, calendar: calendar))
        }
        XCTAssertEqual(DayKey.streak(from: keys, today: today, calendar: calendar), 2)
    }
}