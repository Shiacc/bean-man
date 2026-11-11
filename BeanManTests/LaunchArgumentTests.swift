import XCTest
@testable import BeanMan

/// 截图用的启动参数解析（`-startTab` / `-openScreen`）：解析错了 CI 会拍到错的页面，所以单独测。
@MainActor
final class LaunchArgumentTests: XCTestCase {

    func testStartTabReadsKnownTabs() {
        XCTAssertEqual(AppRouter.initialTab(arguments: ["-startTab", "today"]), .today)
        XCTAssertEqual(AppRouter.initialTab(arguments: ["-startTab", "decks"]), .decks)
        XCTAssertEqual(AppRouter.initialTab(arguments: ["-startTab", "stats"]), .stats)
        XCTAssertEqual(AppRouter.initialTab(arguments: ["-startTab", "settings"]), .settings)
    }

    func testStartTabFallsBackToToday() {
        XCTAssertEqual(AppRouter.initialTab(arguments: []), .today)
        XCTAssertEqual(AppRouter.initialTab(arguments: ["-skipOnboarding"]), .today)
        XCTAssertEqual(AppRouter.initialTab(arguments: ["-startTab"]), .today, "只给 key 不给值时要能扛住")
        XCTAssertEqual(AppRouter.initialTab(arguments: ["-startTab", "nope"]), .today)
    }

    func testStartTabIgnoresOtherArguments() {
        let args = ["-skipOnboarding", "-startTab", "stats", "-openScreen", "share"]
        XCTAssertEqual(AppRouter.initialTab(arguments: args), .stats)
    }

    func testTabNameIsCaseInsensitive() {
        XCTAssertEqual(AppTab(name: "Settings"), .settings)
        XCTAssertEqual(AppTab(name: "STATS"), .stats)
        XCTAssertNil(AppTab(name: "unknown"))
    }
}