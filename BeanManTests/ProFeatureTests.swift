import XCTest
import SwiftData
@testable import BeanMan

/// 免费额度闸门：这层纯函数保证「免费用户不被硬卡死，只在关键动作上引导」。
final class TierGateTests: XCTestCase {

    func testDailyNewIsCappedForFreeUser() {
        XCTAssertEqual(TierGate.maxDailyNew(isPro: false, requested: 40), 20)
        XCTAssertEqual(TierGate.maxDailyNew(isPro: false, requested: 10), 10)
        XCTAssertEqual(TierGate.maxDailyNew(isPro: true, requested: 40), 40)
    }

    func testDeckSlots() {
        XCTAssertEqual(TierGate.remainingDeckSlots(existingCustomDecks: 0, isPro: false), 1)
        XCTAssertEqual(TierGate.remainingDeckSlots(existingCustomDecks: 1, isPro: false), 0)
        XCTAssertTrue(TierGate.canCreateDeck(existingCustomDecks: 0, isPro: false))
        XCTAssertFalse(TierGate.canCreateDeck(existingCustomDecks: 1, isPro: false))
        // Pro 无上限
        XCTAssertTrue(TierGate.canCreateDeck(existingCustomDecks: 9, isPro: true))
    }

    func testWordSlotsAndTruncation() {
        XCTAssertEqual(TierGate.remainingWordSlots(currentWordCount: 480, isPro: false), 20)
        XCTAssertEqual(TierGate.remainingWordSlots(currentWordCount: 600, isPro: false), 0)
        XCTAssertEqual(TierGate.allowedWordCount(requested: 100, currentWordCount: 480, isPro: false), 20)
        // 「还能不能加」只看还有没有剩余槽位；加多少由 allowedWordCount 截断
        XCTAssertTrue(TierGate.canAddWords(currentWordCount: 400, adding: 100, isPro: false))
        XCTAssertTrue(TierGate.canAddWords(currentWordCount: 480, adding: 100, isPro: false))
        XCTAssertFalse(TierGate.canAddWords(currentWordCount: 500, adding: 100, isPro: false))
        // Pro 永远够
        XCTAssertEqual(TierGate.remainingWordSlots(currentWordCount: 10_000, isPro: true), Int.max)
        XCTAssertTrue(TierGate.canAddWords(currentWordCount: 10_000, adding: 999, isPro: true))
    }

    func testAtLimit() {
        XCTAssertTrue(TierGate.isAtLimit(currentWordCount: 500, customDecks: 0, isPro: false))
        XCTAssertTrue(TierGate.isAtLimit(currentWordCount: 0, customDecks: 1, isPro: false))
        XCTAssertFalse(TierGate.isAtLimit(currentWordCount: 0, customDecks: 1, isPro: true))
    }
}

/// 小豆的洞察：只在有数据时说话，且推荐词必须是「错过、没到期、没挂起」的。
@MainActor
final class InsightEngineTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        container = try BeanManStore.makeContainer(inMemory: true)
        context = ModelContext(container)
        BeanManStore.bootstrap(context)
    }

    override func tearDown() async throws {
        context = nil
        container = nil
    }

    func testEmptyLibraryHasNoInsights() throws {
        let snapshot = try InsightEngine.snapshot(context: context)
        XCTAssertTrue(snapshot.recommendations.isEmpty)
    }

    func testRecommendationsPreferMostLapses() throws {
        let words = try context.fetch(FetchDescriptor<Word>(sortBy: [SortDescriptor(\.sortIndex)]))
        XCTAssertGreaterThanOrEqual(words.count, 8)

        // 前 6 个词做错误状态；去掉「今天到期」，让它们成为候选
        let future = DayKey.adding(days: 5, to: Date())
        var expectedFirst: String?
        for (index, word) in words.prefix(6).enumerated() {
            let state = ReviewState(wordID: word.id,
                                    deckID: word.deckID,
                                    easeFactor: 2.2,
                                    intervalDays: 5,
                                    repetitions: 2,
                                    dueDate: future,
                                    lastReviewedAt: Date(),
                                    lapses: index + 1,
                                    phase: .review,
                                    isSuspended: false,
                                    lastRatingRaw: Rating.again.rawValue)
            state.word = word
            context.insert(state)
            word.reviewState = state
            if index == 5 { expectedFirst = word.word }
        }
        try context.save()

        let snapshot = try InsightEngine.snapshot(context: context)
        XCTAssertEqual(snapshot.recommendations.count, InsightEngine.recommendationLimit)
        XCTAssertEqual(snapshot.recommendations.first?.word, expectedFirst)
        XCTAssertEqual(snapshot.recommendedIDs.count, snapshot.recommendations.count)
        XCTAssertTrue(snapshot.recommendations[0].reason.contains("错"))
    }

    func testSuspendedWordsAreNotRecommended() throws {
        let words = try context.fetch(FetchDescriptor<Word>(sortBy: [SortDescriptor(\.sortIndex)]))
        for word in words.prefix(3) {
            let state = ReviewState(wordID: word.id,
                                    deckID: word.deckID,
                                    dueDate: DayKey.adding(days: 9, to: Date()),
                                    lapses: 4,
                                    phase: .review,
                                    isSuspended: true,
                                    lastRatingRaw: Rating.again.rawValue)
            state.word = word
            context.insert(state)
            word.reviewState = state
        }
        try context.save()

        let snapshot = try InsightEngine.snapshot(context: context)
        XCTAssertTrue(snapshot.recommendations.isEmpty)
    }
}

/// 成就：只解锁一次、进度可读、可以整体重置。
@MainActor
final class AchievementCenterTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "beanman.tests.achievements.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func testUnlocksOnceAndReportsCelebration() {
        let center = AchievementCenter(defaults: defaults)
        let metrics = AchievementMetrics(learnedWords: 1,
                                         masteredWords: 0,
                                         streak: 1,
                                         clearedDue: false,
                                         importedDeck: false)

        XCTAssertEqual(center.check(metrics: metrics), 1)
        XCTAssertTrue(center.isUnlocked(.firstStep))
        XCTAssertEqual(center.celebrating, .firstStep)

        // 再次检查不应重复解锁
        XCTAssertEqual(center.check(metrics: metrics), 0)
        XCTAssertNil(center.celebrating)
    }

    func testProgressAndText() {
        let center = AchievementCenter(defaults: defaults)
        let metrics = AchievementMetrics(learnedWords: 500,
                                         masteredWords: 0,
                                         streak: 3,
                                         clearedDue: false,
                                         importedDeck: false)
        XCTAssertEqual(center.progress(for: .thousandWords, metrics: metrics), 0.5, accuracy: 0.001)
        XCTAssertEqual(center.progressText(for: .thousandWords, metrics: metrics), "500 / 1000 词")
        XCTAssertEqual(center.progress(for: .streak7, metrics: metrics), 3.0 / 7.0, accuracy: 0.001)
    }

    func testFlagsAndReset() {
        let center = AchievementCenter(defaults: defaults)
        center.markClearedDue()
        XCTAssertEqual(center.check(metrics: .init(learnedWords: 0,
                                                   masteredWords: 0,
                                                   streak: 0,
                                                   clearedDue: true,
                                                   importedDeck: false)), 1)
        center.resetAll()
        XCTAssertEqual(center.unlockedCount, 0)
        XCTAssertFalse(center.isUnlocked(.clearedDue))
    }
}