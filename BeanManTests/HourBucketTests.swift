import XCTest
@testable import BeanMan

/// 时段分桶：一天四段的边界、正确率、样本数。设置页的柱图直接用这份数据。
final class HourBucketTests: XCTestCase {

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

    private func record(hour: Int, correct: Bool) -> StudyRecord {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 11
        components.hour = hour
        let date = calendar.date(from: components)!
        return StudyRecord(wordID: UUID(),
                           deckID: UUID(),
                           rating: correct ? .good : .again,
                           wasNew: false,
                           reviewedAt: date,
                           newDueDate: date)
    }

    func testBucketsGroupByPeriod() {
        let records = [
            record(hour: 8, correct: true),    // 早上
            record(hour: 10, correct: false),  // 早上
            record(hour: 14, correct: true),   // 下午
            record(hour: 20, correct: false),  // 晚上
            record(hour: 2, correct: true)     // 深夜
        ]

        let buckets = InsightEngine.hourBuckets(records: records, calendar: calendar)

        XCTAssertEqual(buckets.count, 4)
        XCTAssertEqual(buckets.map(\.label), ["早上", "下午", "晚上", "深夜"])
        XCTAssertEqual(buckets.map(\.answered), [2, 1, 1, 1])
        XCTAssertEqual(buckets.map(\.correct), [1, 1, 0, 1])
        XCTAssertEqual(buckets[0].accuracyPercent, 50)
        XCTAssertEqual(buckets[3].accuracyPercent, 100)
        XCTAssertEqual(buckets.reduce(0) { $0 + $1.answered }, records.count)
    }

    func testEmptyRecordsGiveZeroedBuckets() {
        let buckets = InsightEngine.hourBuckets(records: [], calendar: calendar)

        XCTAssertEqual(buckets.count, 4)
        XCTAssertTrue(buckets.allSatisfy { $0.answered == 0 && $0.correct == 0 })
        XCTAssertEqual(buckets[0].accuracy, 0, "没样本时正确率是 0，不是 NaN")
    }

    func testBoundaryHours() {
        // 5 点算早上、11 点算下午、17 点算晚上、23 点算深夜
        let records = [
            record(hour: 5, correct: true),
            record(hour: 11, correct: true),
            record(hour: 17, correct: true),
            record(hour: 23, correct: true)
        ]

        let buckets = InsightEngine.hourBuckets(records: records, calendar: calendar)
        XCTAssertEqual(buckets.map(\.answered), [1, 1, 1, 1])
    }
}