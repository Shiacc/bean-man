import XCTest
import SwiftData
@testable import BeanMan

/// 学习卡的「跳过」（轻点已翻面 / 上滑）：位置往前走，但**不写任何记录**。
/// 这是 PRD §5.3.1 的边界——跳过不能悄悄影响记忆曲线，也不能被「撤销」误伤。
@MainActor
final class StudyViewModelSkipTests: XCTestCase {

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

    func testSkipMovesForwardWithoutWritingAnything() throws {
        let model = StudyViewModel()
        model.start(context: context)
        XCTAssertGreaterThan(model.queue.count, 1, "示例词库至少要能排出一张以上的卡")

        let recordsBefore = try context.fetchCount(FetchDescriptor<StudyRecord>())
        let statesBefore = try context.fetchCount(FetchDescriptor<ReviewState>())
        let firstWordID = model.current?.word.id

        model.skip()

        XCTAssertEqual(model.index, 1)
        XCTAssertEqual(model.skippedCount, 1)
        XCTAssertEqual(model.answeredCount, 0, "跳过不算评分")
        XCTAssertFalse(model.isFlipped, "跳过后新卡应该是正面")
        XCTAssertFalse(model.canUndo, "跳过没有记录可撤")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<StudyRecord>()), recordsBefore)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ReviewState>()), statesBefore, "跳过的词不该被建复习状态")
        XCTAssertNotEqual(model.current?.word.id, firstWordID)
    }

    func testSkippingEverythingFinishesWithoutAnswers() throws {
        let model = StudyViewModel()
        model.start(context: context)
        let total = model.queue.count
        XCTAssertGreaterThan(total, 0)

        for _ in 0..<total {
            model.skip()
        }

        XCTAssertTrue(model.finished)
        XCTAssertEqual(model.skippedCount, total)
        XCTAssertEqual(model.answeredCount, 0)
        XCTAssertEqual(model.summary.accuracy, 0)
    }

    func testRatingAfterSkipStillRecords() throws {
        let model = StudyViewModel()
        model.start(context: context)
        model.skip()
        model.flip()

        let recordsBefore = try context.fetchCount(FetchDescriptor<StudyRecord>())
        model.rate(.good, context: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<StudyRecord>()), recordsBefore + 1)
        XCTAssertEqual(model.answeredCount, 1)
        XCTAssertEqual(model.skippedCount, 1)
        XCTAssertTrue(model.canUndo)
    }
}