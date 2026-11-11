import XCTest
import SwiftData
@testable import BeanMan

/// 统计快照里的「到期预测」和「今日待复习」必须同源——
/// 否则统计页会出现「今日待复习 3」和曲线第一天 2 这种自相矛盾的数字。
@MainActor
final class StatsServiceTests: XCTestCase {

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

    private func words() throws -> [Word] {
        try context.fetch(FetchDescriptor<Word>(sortBy: [SortDescriptor(\.sortIndex)]))
    }

    func testForecastFirstDayMatchesDueToday() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let inThreeDays = calendar.date(byAdding: .day, value: 3, to: today)!
        let inTenDays = calendar.date(byAdding: .day, value: 10, to: today)!

        let all = try words()
        XCTAssertGreaterThanOrEqual(all.count, 5)

        let plan: [(index: Int, due: Date, suspended: Bool)] = [
            (0, yesterday, false),    // 逾期 → 压到今天
            (1, today, false),        // 今天
            (2, inThreeDays, false),  // 3 天后
            (3, inTenDays, false),    // 窗口外
            (4, today, true)          // 挂起 → 两边都不算
        ]
        for item in plan {
            let word = all[item.index]
            let state = ReviewState(wordID: word.id,
                                    deckID: word.deckID,
                                    dueDate: item.due,
                                    phase: .review,
                                    isSuspended: item.suspended)
            state.word = word
            word.reviewState = state
            context.insert(state)
        }
        try context.save()

        let snapshot = try StatsService.snapshot(context: context)

        XCTAssertEqual(snapshot.dueToday, 2)                      // 逾期 + 今天
        XCTAssertEqual(snapshot.forecast.days.count, 7)
        XCTAssertEqual(snapshot.forecast.days[0].due, snapshot.dueToday)
        XCTAssertEqual(snapshot.forecast.overdue, 1)
        XCTAssertEqual(snapshot.forecast.days[3].due, 1)          // 3 天后
        XCTAssertEqual(snapshot.forecast.total, 3)                // 窗口外的不算
    }

    func testEmptyLibraryHasEmptyForecast() throws {
        let snapshot = try StatsService.snapshot(context: context)

        XCTAssertEqual(snapshot.dueToday, 0)
        XCTAssertTrue(snapshot.forecast.isEmpty)
        XCTAssertEqual(snapshot.forecast.total, 0)
        XCTAssertNil(snapshot.forecast.peak)
    }
}