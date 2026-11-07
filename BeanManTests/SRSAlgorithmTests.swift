import XCTest
@testable import BeanMan

final class SRSAlgorithmTests: XCTestCase {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }

    /// 固定「今天」= 2026-11-07 15:30（本地时区），便于断言 dueDate。
    private var now: Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 11; comps.day = 7
        comps.hour = 15; comps.minute = 30
        return calendar.date(from: comps)!
    }

    private func startOfToday() -> Date {
        calendar.startOfDay(for: now)
    }

    // MARK: - 四个档位

    func testAgainResetsProgress() {
        let out = SRSAlgorithm.schedule(easeFactor: 2.5, intervalDays: 10, repetitions: 4, lapses: 1,
                                        rating: .again, now: now, calendar: calendar)
        XCTAssertEqual(out.repetitions, 0)
        XCTAssertEqual(out.intervalDays, 1)
        XCTAssertEqual(out.lapses, 2)
        XCTAssertEqual(out.easeFactor, 2.3, accuracy: 0.0001)
        XCTAssertEqual(out.phase, .relearning)
        XCTAssertEqual(out.dueDate, calendar.date(byAdding: .day, value: 1, to: startOfToday()))
    }

    func testHardGrowsSlowlyAndLowersEase() {
        let out = SRSAlgorithm.schedule(easeFactor: 2.5, intervalDays: 10, repetitions: 2, lapses: 0,
                                        rating: .hard, now: now, calendar: calendar)
        XCTAssertEqual(out.repetitions, 3)
        XCTAssertEqual(out.intervalDays, 12)     // max(11, round(12)) = 12
        XCTAssertEqual(out.easeFactor, 2.35, accuracy: 0.0001)
        XCTAssertEqual(out.phase, .review)
    }

    func testGoodMultipliesByEase() {
        let out = SRSAlgorithm.schedule(easeFactor: 2.5, intervalDays: 10, repetitions: 3, lapses: 0,
                                        rating: .good, now: now, calendar: calendar)
        XCTAssertEqual(out.repetitions, 4)
        XCTAssertEqual(out.intervalDays, 25)     // round(10 * 2.5)
        XCTAssertEqual(out.easeFactor, 2.5, accuracy: 0.0001)
    }

    func testEasyGrowsFasterAndRaisesEase() {
        let out = SRSAlgorithm.schedule(easeFactor: 2.0, intervalDays: 10, repetitions: 3, lapses: 0,
                                        rating: .easy, now: now, calendar: calendar)
        XCTAssertEqual(out.repetitions, 4)
        XCTAssertEqual(out.intervalDays, 26)     // round(10 * 2.0 * 1.3)
        XCTAssertEqual(out.easeFactor, 2.15, accuracy: 0.0001)
    }

    // MARK: - 新词的初始档位

    func testNewWordIntervals() {
        let good = SRSAlgorithm.schedule(easeFactor: 2.5, intervalDays: 0, repetitions: 0, lapses: 0,
                                         rating: .good, now: now, calendar: calendar)
        XCTAssertEqual(good.intervalDays, 1)
        XCTAssertEqual(good.phase, .learning)

        let second = SRSAlgorithm.schedule(easeFactor: 2.5, intervalDays: 1, repetitions: 1, lapses: 0,
                                           rating: .good, now: now, calendar: calendar)
        XCTAssertEqual(second.intervalDays, 3)

        let easy = SRSAlgorithm.schedule(easeFactor: 2.5, intervalDays: 0, repetitions: 0, lapses: 0,
                                         rating: .easy, now: now, calendar: calendar)
        XCTAssertEqual(easy.intervalDays, 4)
    }

    // MARK: - 边界

    func testEaseNeverBelowFloor() {
        var ease = 2.5
        for _ in 0..<20 {
            let out = SRSAlgorithm.schedule(easeFactor: ease, intervalDays: 3, repetitions: 1, lapses: 0,
                                            rating: .again, now: now, calendar: calendar)
            ease = out.easeFactor
        }
        XCTAssertEqual(ease, SRSAlgorithm.minEase, accuracy: 0.0001)
    }

    func testEaseNeverAboveCeiling() {
        var ease = 2.5
        for _ in 0..<20 {
            let out = SRSAlgorithm.schedule(easeFactor: ease, intervalDays: 3, repetitions: 1, lapses: 0,
                                            rating: .easy, now: now, calendar: calendar)
            ease = out.easeFactor
        }
        XCTAssertEqual(ease, SRSAlgorithm.maxEase, accuracy: 0.0001)
    }

    func testIntervalIsClamped() {
        let out = SRSAlgorithm.schedule(easeFactor: 3.0, intervalDays: 300, repetitions: 8, lapses: 0,
                                        rating: .easy, now: now, calendar: calendar)
        XCTAssertLessThanOrEqual(out.intervalDays, SRSAlgorithm.maxInterval)
        XCTAssertGreaterThanOrEqual(out.intervalDays, 1)
    }

    func testDueDateIsStartOfDayPlusInterval() {
        let out = SRSAlgorithm.schedule(easeFactor: 2.5, intervalDays: 0, repetitions: 0, lapses: 0,
                                        rating: .good, now: now, calendar: calendar)
        let expected = calendar.date(byAdding: .day, value: out.intervalDays, to: startOfToday())
        XCTAssertEqual(out.dueDate, expected)
        // 不存在「今天 15:30 + 1 天」这种带时分秒的到期时间
        let comps = calendar.dateComponents([.hour, .minute], from: out.dueDate)
        XCTAssertEqual(comps.hour, 0)
        XCTAssertEqual(comps.minute, 0)
    }
}