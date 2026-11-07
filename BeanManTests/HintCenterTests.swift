import XCTest
@testable import BeanMan

/// 纯逻辑测试：不碰 SwiftUI，也不碰磁盘。
final class HintSchedulerTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_760_000_000)

    func testOnceOnly_ShowsOnceThenSkips() {
        var scheduler = HintScheduler()
        let request = HintRequest(id: "a", onceOnly: true)

        XCTAssertEqual(scheduler.decide(request, current: nil, now: t0), .show)
        scheduler.markShown(request, now: t0)

        XCTAssertEqual(scheduler.decide(request, current: nil, now: t0.addingTimeInterval(3600)), .skipOnce)
    }

    func testCooldown_BlocksUntilElapsed() {
        var scheduler = HintScheduler()
        let request = HintRequest(id: "b", onceOnly: false, cooldown: 60)

        XCTAssertEqual(scheduler.decide(request, current: nil, now: t0), .show)
        scheduler.markShown(request, now: t0)

        XCTAssertEqual(scheduler.decide(request, current: nil, now: t0.addingTimeInterval(30)), .skipCooldown)
        XCTAssertEqual(scheduler.decide(request, current: nil, now: t0.addingTimeInterval(61)), .show)
    }

    func testHigherPriorityPreemptsLower() {
        let scheduler = HintScheduler()
        let showing = HintRequest(id: "big", priority: 100)
        let small = HintRequest(id: "small", priority: 1)

        XCTAssertEqual(scheduler.decide(small, current: showing, now: t0), .skipBusy)
    }

    func testSamePriorityIsAllowed() {
        let scheduler = HintScheduler()
        let showing = HintRequest(id: "a", priority: 10)
        let next = HintRequest(id: "b", priority: 10)

        XCTAssertEqual(scheduler.decide(next, current: showing, now: t0), .show)
    }

    func testRepeatedSameIdWhileVisibleIsAllowed() {
        let scheduler = HintScheduler()
        let request = HintRequest(id: "a", priority: 10)

        XCTAssertEqual(scheduler.decide(request, current: request, now: t0), .show)
    }
}

/// 带持久化的版本：用独立 UserDefaults suite，测试后清掉。
@MainActor
final class HintCenterTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        suiteName = "hint.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func testRequestThenDismiss() {
        let center = HintCenter(defaults: defaults)
        let request = HintRequest(id: "today.startStudy")

        XCTAssertNil(center.current)
        XCTAssertEqual(center.request(request), .show)
        XCTAssertEqual(center.current?.id, "today.startStudy")

        center.dismiss()
        XCTAssertNil(center.current)
    }

    func testOnceOnlySurvivesSecondRequest() {
        let center = HintCenter(defaults: defaults)
        let request = HintRequest(id: "today.startStudy")

        XCTAssertEqual(center.request(request), .show)
        center.dismiss()

        XCTAssertEqual(center.request(request), .skipOnce)
        XCTAssertTrue(center.hasSeen("today.startStudy"))
    }

    func testSeenStatePersistsAcrossInstances() {
        let first = HintCenter(defaults: defaults)
        XCTAssertEqual(first.request(HintRequest(id: "study.flipCard")), .show)
        first.dismiss()

        let second = HintCenter(defaults: defaults)
        XCTAssertTrue(second.hasSeen("study.flipCard"))
        XCTAssertEqual(second.request(HintRequest(id: "study.flipCard")), .skipOnce)
    }

    func testResetAllAllowsShowingAgain() {
        let center = HintCenter(defaults: defaults)
        let request = HintRequest(id: "today.statTiles")

        XCTAssertEqual(center.request(request), .show)
        center.dismiss()
        XCTAssertEqual(center.request(request), .skipOnce)

        center.resetAll()
        XCTAssertFalse(center.hasSeen("today.statTiles"))
        XCTAssertEqual(center.request(request), .show)
    }

    func testHighPriorityBlocksLowPriority() {
        let center = HintCenter(defaults: defaults)
        XCTAssertEqual(center.request(HintRequest(id: "big", priority: 100)), .show)
        XCTAssertEqual(center.request(HintRequest(id: "small", priority: 1)), .skipBusy)
        XCTAssertEqual(center.current?.id, "big")
    }

    func testCopyExistsForEveryHintID() {
        let ids = [
            HintID.todayStartStudy,
            HintID.todayStatTiles,
            HintID.studyFlipCard,
            HintID.studyRateButtons
        ]
        for id in ids {
            let copy = HintCopy.of(id)
            XCTAssertFalse(copy.title.isEmpty, "\(id) 缺标题")
            XCTAssertFalse(copy.message.isEmpty, "\(id) 缺正文")
            XCTAssertFalse(copy.actionTitle.isEmpty, "\(id) 缺按钮文案")
        }
    }
}