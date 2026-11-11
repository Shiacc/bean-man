import XCTest
@testable import BeanMan

/// 未来 7 天到期预测：口径必须和「今日待复习」一致，逾期压到今天，窗口外不借数字。
final class ForecastServiceTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        self.calendar = calendar
    }

    override func tearDown() async throws {
        calendar = nil
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar.date(from: components)!
    }

    func testBucketsOverdueIntoToday() {
        let now = date(2026, 11, 11, hour: 10)
        let entries = [
            DueEntry(dueDate: date(2026, 11, 9)),          // 逾期
            DueEntry(dueDate: date(2026, 11, 11, hour: 9)), // 今天
            DueEntry(dueDate: date(2026, 11, 12)),          // 明天
            DueEntry(dueDate: date(2026, 11, 13, hour: 23)),// 后天
            DueEntry(dueDate: date(2026, 11, 20))           // 窗口外
        ]

        let snapshot = ForecastService.snapshot(entries: entries, now: now, calendar: calendar)

        XCTAssertEqual(snapshot.days.count, 7)
        XCTAssertEqual(snapshot.overdue, 1)
        XCTAssertEqual(snapshot.days[0].due, 2)   // 逾期 + 今天
        XCTAssertEqual(snapshot.days[1].due, 1)
        XCTAssertEqual(snapshot.days[2].due, 1)
        XCTAssertEqual(snapshot.days[3].due, 0)
        XCTAssertEqual(snapshot.total, 4)         // 窗口外的不算
        XCTAssertFalse(snapshot.isEmpty)
    }

    func testSuspendedWordsAreIgnored() {
        let now = date(2026, 11, 11, hour: 8)
        let entries = [
            DueEntry(dueDate: date(2026, 11, 11), isSuspended: true),
            DueEntry(dueDate: date(2026, 11, 12), isSuspended: true),
            DueEntry(dueDate: date(2026, 11, 12))
        ]

        let snapshot = ForecastService.snapshot(entries: entries, now: now, calendar: calendar)

        XCTAssertEqual(snapshot.days[0].due, 0)
        XCTAssertEqual(snapshot.days[1].due, 1)
        XCTAssertEqual(snapshot.total, 1)
    }

    func testLabelsAndDayKey() {
        let now = date(2026, 11, 11, hour: 12)
        let snapshot = ForecastService.snapshot(entries: [], now: now, calendar: calendar)

        XCTAssertEqual(snapshot.days[0].dayKey, "2026-11-11")
        XCTAssertEqual(snapshot.days[0].label, "今天")
        XCTAssertTrue(snapshot.days[0].isToday)
        XCTAssertEqual(snapshot.days[1].label, "明天")
        XCTAssertFalse(snapshot.days[1].isToday)
        XCTAssertEqual(snapshot.days[2].label, "11/13")
    }

    func testEmptyForecast() {
        let now = date(2026, 11, 11)
        let snapshot = ForecastService.snapshot(entries: [], now: now, calendar: calendar)

        XCTAssertTrue(snapshot.isEmpty)
        XCTAssertEqual(snapshot.total, 0)
        XCTAssertNil(snapshot.peak)
        XCTAssertEqual(snapshot.overdue, 0)
    }

    func testPeakPicksBusiestDay() {
        let now = date(2026, 11, 11)
        var entries: [DueEntry] = []
        entries.append(contentsOf: (0..<2).map { _ in DueEntry(dueDate: date(2026, 11, 12)) })
        entries.append(contentsOf: (0..<3).map { _ in DueEntry(dueDate: date(2026, 11, 13)) })

        let snapshot = ForecastService.snapshot(entries: entries, now: now, calendar: calendar)

        XCTAssertEqual(snapshot.peak?.offset, 2)
        XCTAssertEqual(snapshot.peak?.due, 3)
    }

    func testPeakTieGoesToEarlierDay() {
        let now = date(2026, 11, 11)
        let entries = [
            DueEntry(dueDate: date(2026, 11, 12)),
            DueEntry(dueDate: date(2026, 11, 12)),
            DueEntry(dueDate: date(2026, 11, 14)),
            DueEntry(dueDate: date(2026, 11, 14))
        ]

        let snapshot = ForecastService.snapshot(entries: entries, now: now, calendar: calendar)

        XCTAssertEqual(snapshot.peak?.offset, 1)
    }

    func testHorizonLengthIsRespected() {
        let now = date(2026, 11, 11)
        let entries = [
            DueEntry(dueDate: date(2026, 11, 12)),
            DueEntry(dueDate: date(2026, 11, 15))
        ]

        let snapshot = ForecastService.snapshot(entries: entries, now: now, horizon: 3, calendar: calendar)

        XCTAssertEqual(snapshot.days.count, 3)
        XCTAssertEqual(snapshot.total, 1)
    }

    func testEntriesFromReviewStates() {
        let state = ReviewState(wordID: UUID(),
                                deckID: UUID(),
                                dueDate: date(2026, 11, 12),
                                isSuspended: true)
        let entries = ForecastService.entries(from: [state])

        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(entries[0].isSuspended)
        XCTAssertEqual(entries[0].dueDate, date(2026, 11, 12))
    }
}