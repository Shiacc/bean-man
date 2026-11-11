import XCTest
@testable import BeanMan

/// 小豆洞察的展示规则（AC-66）：dismiss 后 7 天冷却、重复 dismiss 不续命、每天最多 3 条、重装前一直记得。
@MainActor
final class InsightCenterTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "beanman.tests.insights.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    private func makeInsight(_ kind: Insight.Kind, id: String) -> Insight {
        Insight(id: id, kind: kind, title: "标题", detail: "说明", actionTitle: nil)
    }

    private var baseTime: Date { Date(timeIntervalSince1970: 1_800_000_000) }

    func testDismissCoolsDownForSevenDays() {
        let center = InsightCenter(defaults: defaults)
        XCTAssertTrue(center.dismiss(.backlog, now: baseTime))

        XCTAssertTrue(center.isDismissed(.backlog, now: baseTime))
        XCTAssertTrue(center.isDismissed(.backlog, now: baseTime.addingTimeInterval(6 * 24 * 3600)))
        XCTAssertFalse(center.isDismissed(.backlog, now: baseTime.addingTimeInterval(8 * 24 * 3600)),
                       "7 天冷却过了就该重新允许展示")
    }

    func testDismissingAgainDoesNotExtendCooldown() {
        let center = InsightCenter(defaults: defaults)
        center.dismiss(.backlog, now: baseTime)

        XCTAssertFalse(center.dismiss(.backlog, now: baseTime.addingTimeInterval(3_600)),
                       "冷却期内再点「知道了」不该刷新计时")

        let afterCooldown = baseTime.addingTimeInterval(7 * 24 * 3600 + 60)
        XCTAssertFalse(center.isDismissed(.backlog, now: afterCooldown))
    }

    func testOtherKindsAreNotAffected() {
        let center = InsightCenter(defaults: defaults)
        center.dismiss(.backlog, now: baseTime)
        XCTAssertFalse(center.isDismissed(.wrongWords, now: baseTime))
    }

    func testVisibleFiltersDismissedAndCapsAtThree() {
        let center = InsightCenter(defaults: defaults)
        center.dismiss(.backlog, now: baseTime)

        let list = [
            makeInsight(.backlog, id: "a"),
            makeInsight(.wrongWords, id: "b"),
            makeInsight(.streakRisk, id: "c"),
            makeInsight(.bestHour, id: "d"),
            makeInsight(.firstWeek, id: "e")
        ]

        let visible = center.visible(list, now: baseTime)
        XCTAssertEqual(visible.map(\.id), ["b", "c", "d"])
    }

    func testPersistenceAcrossInstances() {
        let first = InsightCenter(defaults: defaults)
        first.dismiss(.bestHour, now: baseTime)

        let second = InsightCenter(defaults: defaults)
        XCTAssertTrue(second.isDismissed(.bestHour, now: baseTime),
                      "换一个实例（重启 App）也要记得")
    }

    func testResetAll() {
        let center = InsightCenter(defaults: defaults)
        center.dismiss(.bestHour, now: baseTime)
        center.resetAll()

        XCTAssertFalse(center.isDismissed(.bestHour, now: baseTime))
        XCTAssertEqual(center.visible([makeInsight(.bestHour, id: "a")], now: baseTime).count, 1)
    }
}