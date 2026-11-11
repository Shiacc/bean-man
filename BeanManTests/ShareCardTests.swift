import XCTest
@testable import BeanMan

/// 分享卡的文案与尺寸：允许改版式，但不允许「分享出去的数字和 App 里不一样」。
final class ShareCardContentTests: XCTestCase {

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

    private var fixedNow: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 11
        components.hour = 21
        return calendar.date(from: components)!
    }

    private func make(streak: Int,
                      learnedToday: Int,
                      learnedWords: Int,
                      dueToday: Int) -> ShareCardContent {
        ShareCardContent.make(streak: streak,
                              learnedToday: learnedToday,
                              learnedWords: learnedWords,
                              dueToday: dueToday,
                              now: fixedNow,
                              calendar: calendar)
    }

    func testWeeklyStreakCopy() {
        let content = make(streak: 7, learnedToday: 18, learnedWords: 236, dueToday: 0)

        XCTAssertEqual(content.headline, "坚持了 7 天")
        XCTAssertEqual(content.subtitle, "一周了，别断")
        XCTAssertEqual(content.quote, "今天的账清了")
        XCTAssertEqual(content.dateText, "2026 年 11 月 11 日")
        XCTAssertEqual(content.stats.map(\.value), ["7", "18", "236"])
        XCTAssertEqual(content.stats.map(\.unit), ["天", "个", "词"])
        XCTAssertEqual(content.stats.map(\.label), ["连续打卡", "今日已学", "累计学过"])
    }

    func testFirstDayCopy() {
        let content = make(streak: 0, learnedToday: 0, learnedWords: 0, dueToday: 0)

        XCTAssertEqual(content.headline, "今天开始")
        XCTAssertEqual(content.subtitle, "第一个词，开始了")
        XCTAssertEqual(content.quote, "慢慢来，比一次背很多有用")
        XCTAssertEqual(content.stats.first?.value, "0")
    }

    func testSingleDayCopy() {
        let content = make(streak: 1, learnedToday: 5, learnedWords: 5, dueToday: 3)

        XCTAssertEqual(content.headline, "打卡第 1 天")
        XCTAssertEqual(content.subtitle, "每天一点，比一次背很多有用")
        // 还有到期词没清，不能吹「账清了」
        XCTAssertEqual(content.quote, "今天记住一个也算赢")
    }

    func testNegativeInputsAreClamped() {
        let content = make(streak: -3, learnedToday: -1, learnedWords: -2, dueToday: -4)

        XCTAssertEqual(content.headline, "今天开始")
        XCTAssertEqual(content.stats.map(\.value), ["0", "0", "0"])
        XCTAssertFalse(content.dateText.isEmpty)
    }

    func testWatermarkIsStable() {
        let content = make(streak: 30, learnedToday: 20, learnedWords: 800, dueToday: 0)
        XCTAssertEqual(content.watermark, "BeanMan · 豆卡单词")
        XCTAssertEqual(content.kicker, "豆卡单词 · 打卡")
    }
}

/// 导出尺寸必须是 1080 × 1350（AC-80），不靠截图工具裁。
final class ShareCardSpecTests: XCTestCase {

    func testPixelSizeIs1080By1350() {
        XCTAssertEqual(ShareCardSpec.pixelSize.width, 1080)
        XCTAssertEqual(ShareCardSpec.pixelSize.height, 1350)
    }

    func testAspectRatioIsFourByFive() {
        let ratio = ShareCardSpec.pointSize.width / ShareCardSpec.pointSize.height
        XCTAssertEqual(ratio, 0.8, accuracy: 0.0001)
    }
}