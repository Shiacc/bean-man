import XCTest
import SwiftData
@testable import BeanMan

/// 弹幕复习只做两件事：按时间滚、能暂停。这两件事必须能脱离 UI 验。
@MainActor
final class DanmakuReviewViewModelTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "beanman.tests.danmaku.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    private func makeViewModel(lines: Int = 4) -> DanmakuReviewViewModel {
        let vm = DanmakuReviewViewModel(defaults: defaults)
        vm.load(lines: (0..<lines).map { index in
            .init(id: UUID(),
                  word: "word\(index)",
                  phonetic: "[w\(index)]",
                  partOfSpeech: "n.",
                  meaning: "释义\(index)")
        })
        return vm
    }

    func testElapsedGrowsWithClock() throws {
        let vm = makeViewModel()
        let t0 = Date()
        // load 之后处于「运行中」，resumedAt = 现在；用显式时钟验证增长速度
        vm.seek(accumulated: 0, resumedAt: t0)
        XCTAssertEqual(vm.elapsed(at: t0), 0, accuracy: 0.001)
        XCTAssertEqual(vm.elapsed(at: t0.addingTimeInterval(2)), 2, accuracy: 0.001)
    }

    func testPauseFreezesAndResumeContinues() throws {
        let vm = makeViewModel()
        let t0 = Date()
        vm.seek(accumulated: 0, resumedAt: t0)

        vm.togglePause(now: t0.addingTimeInterval(3))
        XCTAssertTrue(vm.isPaused)
        // 暂停之后时间继续走，但位置不动
        XCTAssertEqual(vm.elapsed(at: t0.addingTimeInterval(10)), 3, accuracy: 0.001)

        vm.togglePause(now: t0.addingTimeInterval(10))
        XCTAssertFalse(vm.isPaused)
        XCTAssertEqual(vm.elapsed(at: t0.addingTimeInterval(12)), 5, accuracy: 0.001)
    }

    func testOffsetWrapsAroundContent() throws {
        let vm = makeViewModel(lines: 4)
        let t0 = Date()
        vm.seek(accumulated: 0, resumedAt: t0)

        let total = 4 * DanmakuReviewViewModel.blockHeight
        // 滚很久也只会在内容高度内循环
        for seconds in [1.0, 10.0, 60.0, 360.0] {
            let offset = vm.offset(at: t0.addingTimeInterval(seconds))
            XCTAssertGreaterThanOrEqual(offset, 0)
            XCTAssertLessThan(offset, total)
        }
    }

    func testSpeedChangeKeepsPosition() throws {
        let vm = makeViewModel()
        let t0 = Date()
        vm.seek(accumulated: 0, resumedAt: t0)
        let before = vm.elapsed(at: Date())
        vm.setSpeed(2.0)
        let after = vm.elapsed(at: Date())
        XCTAssertEqual(before, after, accuracy: 0.05)
        XCTAssertEqual(vm.speedText, "2×")
    }

    func testThemeToggles() throws {
        let vm = makeViewModel()
        XCTAssertEqual(vm.theme, .dark)
        vm.toggleTheme()
        XCTAssertEqual(vm.theme, .light)
        vm.toggleTheme()
        XCTAssertEqual(vm.theme, .dark)
    }

    func testLoadReadsDeckWords() throws {
        let container = try BeanManStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        BeanManStore.bootstrap(context)

        let vm = DanmakuReviewViewModel(defaults: defaults)
        vm.load(context: context)

        XCTAssertFalse(vm.lines.isEmpty)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.lines[0].word.isEmpty)
    }
}