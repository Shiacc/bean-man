import XCTest
import SwiftData
@testable import BeanMan

/// 错词本的派生规则与排序。
///
/// 这里的重点不是 UI，而是「什么算错词」「移出之后还能不能回来」「复习队列怎么排」。
@MainActor
final class WrongBookServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        container = BeanManStore.makeContainer(inMemory: true)
        context = ModelContext(container)
        BeanManStore.bootstrap(context)
    }

    override func tearDown() async throws {
        context = nil
        container = nil
    }

    // MARK: - 工具

    private func words() throws -> [Word] {
        try context.fetch(FetchDescriptor<Word>(sortBy: [SortDescriptor(\.sortIndex)]))
    }

    @discardableResult
    private func giveState(_ word: Word,
                           lapses: Int = 0,
                           lastRating: Rating? = nil,
                           dueIn days: Int = 0,
                           hidden: Bool = false,
                           suspended: Bool = false) -> ReviewState {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let due = calendar.date(byAdding: .day, value: days, to: today) ?? today
        let state = ReviewState(wordID: word.id,
                                deckID: word.deckID,
                                easeFactor: 2.5,
                                intervalDays: 3,
                                repetitions: 2,
                                dueDate: due,
                                lastReviewedAt: calendar.date(byAdding: .day, value: -1, to: today),
                                lapses: lapses,
                                phase: .review,
                                isSuspended: suspended,
                                lastRatingRaw: lastRating?.rawValue,
                                wrongBookHiddenAt: hidden ? Date() : nil)
        state.word = word
        word.reviewState = state
        context.insert(state)
        try? context.save()
        return state
    }

    // MARK: - 派生规则

    func testWrongWordsComeFromLapsesOrLastRating() throws {
        let all = try words()
        giveState(all[0], lapses: 0, lastRating: .again)   // 判过不认识 → 进
        giveState(all[1], lapses: 0, lastRating: .hard)    // 判过模糊 → 进
        giveState(all[2], lapses: 2, lastRating: .good)    // 错过两次 → 进
        giveState(all[3], lapses: 0, lastRating: .good)    // 一直认识 → 不进
        giveState(all[4], lapses: 1, suspended: true)      // 挂起 → 不进

        let snapshot = try WrongBookService.snapshot(context: context)
        let ids = Set(snapshot.entries.map { $0.id })

        XCTAssertTrue(ids.contains(all[0].id))
        XCTAssertTrue(ids.contains(all[1].id))
        XCTAssertTrue(ids.contains(all[2].id))
        XCTAssertFalse(ids.contains(all[3].id))
        XCTAssertFalse(ids.contains(all[4].id))
        XCTAssertEqual(snapshot.visibleCount, 3)
    }

    func testEntryCarriesReasonAndDueState() throws {
        let all = try words()
        giveState(all[0], lapses: 3, lastRating: .again, dueIn: 0)
        giveState(all[1], lapses: 0, lastRating: .hard, dueIn: 2)

        let snapshot = try WrongBookService.snapshot(context: context)
        let first = try XCTUnwrap(snapshot.entries.first { $0.id == all[0].id })
        XCTAssertEqual(first.wrongCount, 3)
        XCTAssertEqual(first.lastRating, .again)
        XCTAssertTrue(first.isDue)
        XCTAssertEqual(first.reasonText, "错了 3 次")

        let second = try XCTUnwrap(snapshot.entries.first { $0.id == all[1].id })
        XCTAssertFalse(second.isDue)
        XCTAssertEqual(second.reasonText, "上次：模糊")
    }

    // MARK: - 移出 / 恢复

    func testHideAndRestore() throws {
        let all = try words()
        giveState(all[0], lapses: 2, lastRating: .again)

        var snapshot = try WrongBookService.snapshot(context: context)
        XCTAssertEqual(snapshot.visibleCount, 1)
        XCTAssertEqual(snapshot.hiddenCount, 0)

        let hidden = try WrongBookService.hide(all[0], context: context)
        XCTAssertTrue(hidden)

        snapshot = try WrongBookService.snapshot(context: context)
        XCTAssertEqual(snapshot.visibleCount, 0)
        XCTAssertEqual(snapshot.hiddenCount, 1)
        XCTAssertEqual(snapshot.totalCount, 1)

        try WrongBookService.restore(all[0], context: context)
        snapshot = try WrongBookService.snapshot(context: context)
        XCTAssertEqual(snapshot.visibleCount, 1)
        XCTAssertEqual(snapshot.hiddenCount, 0)
    }

    func testNewWrongRatingBringsHiddenWordBack() throws {
        let all = try words()
        giveState(all[0], lapses: 1, lastRating: .again, hidden: true)

        var snapshot = try WrongBookService.snapshot(context: context)
        XCTAssertEqual(snapshot.visibleCount, 0)

        // 又判了一次「不认识」
        let item = QueueItem(id: all[0].id, word: all[0], isNew: false)
        try StudyRepository.apply(rating: .again, to: item, context: context)

        snapshot = try WrongBookService.snapshot(context: context)
        XCTAssertEqual(snapshot.visibleCount, 1)
        XCTAssertNil(all[0].reviewState?.wrongBookHiddenAt)
    }

    func testCorrectRatingDoesNotRemoveWordAutomatically() throws {
        let all = try words()
        giveState(all[0], lapses: 2, lastRating: .again)

        let item = QueueItem(id: all[0].id, word: all[0], isNew: false)
        try StudyRepository.apply(rating: .good, to: item, context: context)

        // 错过的词不会因为一次「认识」就消失，只是最近评分变了
        let snapshot = try WrongBookService.snapshot(context: context)
        XCTAssertEqual(snapshot.visibleCount, 1)
        XCTAssertEqual(all[0].reviewState?.lastRating, .good)
    }

    // MARK: - 复习队列

    func testReviewQueuePutsDueFirstAndRespectsLimit() throws {
        let all = try words()
        giveState(all[0], lapses: 1, lastRating: .again, dueIn: 0)   // 今天到期
        giveState(all[1], lapses: 5, lastRating: .again, dueIn: 0)   // 今天到期，错得最多
        giveState(all[2], lapses: 9, lastRating: .hard, dueIn: 3)    // 还没到期
        giveState(all[3], lapses: 0, lastRating: .hard, dueIn: 0)    // 今天到期

        let queue = try WrongBookService.reviewQueue(context: context, limit: 3)

        XCTAssertEqual(queue.count, 3)
        XCTAssertEqual(queue.first?.word.id, all[1].id)   // 到期 + 错最多
        XCTAssertFalse(queue.contains { $0.word.id == all[2].id })  // 没到期的排最后，被截掉
        XCTAssertTrue(queue.allSatisfy { !$0.isNew })
    }

    func testReviewQueueSkipsHiddenWords() throws {
        let all = try words()
        giveState(all[0], lapses: 2, lastRating: .again, dueIn: 0, hidden: true)
        giveState(all[1], lapses: 2, lastRating: .again, dueIn: 0)

        let queue = try WrongBookService.reviewQueue(context: context, limit: 20)
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.word.id, all[1].id)
    }

    func testReviewQueueLimitZeroIsEmpty() throws {
        let all = try words()
        giveState(all[0], lapses: 2, lastRating: .again, dueIn: 0)
        XCTAssertTrue(try WrongBookService.reviewQueue(context: context, limit: 0).isEmpty)
    }

    // MARK: - 空状态

    func testEmptyWhenNothingWrong() throws {
        let snapshot = try WrongBookService.snapshot(context: context)
        XCTAssertTrue(snapshot.entries.isEmpty)
        XCTAssertEqual(snapshot.visibleCount, 0)
        XCTAssertEqual(try WrongBookService.visibleCount(context: context), 0)
    }
}