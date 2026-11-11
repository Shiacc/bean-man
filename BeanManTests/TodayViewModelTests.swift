import XCTest
import SwiftData
@testable import BeanMan

/// 今日页的「跨夜」行为（AC-08）：回到前台或停留过夜时，日期一变就要重算。
@MainActor
final class TodayViewModelTests: XCTestCase {

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

    func testRefreshRecordsTodayKey() {
        let model = TodayViewModel()
        XCTAssertNil(model.lastDayKey)

        model.refresh(context: context)

        XCTAssertEqual(model.lastDayKey, DayKey.string(for: Date()))
    }

    func testSameDayDoesNotRecompute() {
        let model = TodayViewModel()
        model.refresh(context: context)
        let before = model.counts

        model.refreshIfDayChanged(context: context)

        XCTAssertEqual(model.counts, before)
        XCTAssertEqual(model.lastDayKey, DayKey.string(for: Date()))
    }

    func testCrossingMidnightRecomputesCounts() throws {
        let words = try context.fetch(FetchDescriptor<Word>(sortBy: [SortDescriptor(\.sortIndex)]))
        guard let word = words.first else {
            return XCTFail("示例词库没装成功")
        }

        let yesterday = DayKey.adding(days: -1, to: Date())
        let record = StudyRecord(wordID: word.id,
                                 deckID: word.deckID,
                                 rating: .good,
                                 wasNew: false,
                                 reviewedAt: yesterday,
                                 newDueDate: Date())
        context.insert(record)
        try context.save()

        let model = TodayViewModel()
        // 把「现在」当成昨天：昨天那条记录应该被算成今日已学
        model.refresh(context: context, now: yesterday)
        XCTAssertEqual(model.counts.learnedToday, 1)
        XCTAssertEqual(model.lastDayKey, DayKey.string(for: yesterday))

        // 今天再回到前台：日期变了，数字要跟着换
        model.refreshIfDayChanged(context: context)
        XCTAssertEqual(model.counts.learnedToday, 0, "跨夜后「今日已学」必须归零")
        XCTAssertEqual(model.lastDayKey, DayKey.string(for: Date()))
    }
}