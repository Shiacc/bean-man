import XCTest
import SwiftData
@testable import BeanMan

/// F7 抽题与判分的单测。
/// 只用内存库 + 手建 Word / ReviewState，不依赖示例词库。
@MainActor
final class QuizServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        container = try BeanManStore.makeContainer(inMemory: true)
        context = ModelContext(container)
    }

    override func tearDown() async throws {
        context = nil
        container = nil
    }

    // MARK: - 抽题

    func testNeedsAtLeastFourLearnedWords() throws {
        try makeWords(count: 3, learned: true)
        XCTAssertTrue(QuizService.makeQuiz(from: allWords()).isEmpty)

        try makeWords(count: 1, learned: true)
        XCTAssertEqual(QuizService.makeQuiz(from: allWords()).count, 4)
    }

    func testUnlearnedWordsAreNotUsed() throws {
        try makeWords(count: 6, learned: false)
        XCTAssertTrue(QuizService.makeQuiz(from: allWords()).isEmpty)
    }

    func testTenQuestionsFollowFourThreeThree() throws {
        try makeWords(count: 12, learned: true)
        let quiz = QuizService.makeQuiz(from: allWords(), count: 10, seed: 7)
        XCTAssertEqual(quiz.count, 10)

        let kinds = quiz.map(\.kind)
        XCTAssertEqual(kinds.filter { $0 == .meaning }.count, 4)
        XCTAssertEqual(kinds.filter { $0 == .spelling }.count, 3)
        XCTAssertEqual(kinds.filter { $0 == .listening }.count, 3)
    }

    func testSameSeedGivesSameQuiz() throws {
        try makeWords(count: 10, learned: true)
        let a = QuizService.makeQuiz(from: allWords(), count: 6, seed: 42)
        let b = QuizService.makeQuiz(from: allWords(), count: 6, seed: 42)
        XCTAssertEqual(a.map(\.wordID), b.map(\.wordID))
        XCTAssertEqual(a.map(\.kind), b.map(\.kind))
    }

    func testNoRepeatedWordWithinOneQuiz() throws {
        try makeWords(count: 10, learned: true)
        let quiz = QuizService.makeQuiz(from: allWords(), count: 10, seed: 1)
        XCTAssertEqual(Set(quiz.map(\.wordID)).count, quiz.count)
    }

    func testChoiceQuestionsHaveFourUniqueOptionsContainingAnswer() throws {
        try makeWords(count: 8, learned: true)
        let quiz = QuizService.makeQuiz(from: allWords(), count: 8, seed: 3)

        for question in quiz where question.kind != .spelling {
            XCTAssertEqual(question.options.count, 4, "\(question.kind) 应该有 4 个选项")
            XCTAssertEqual(Set(question.options).count, 4, "选项不应重复")
            XCTAssertTrue(question.options.contains(question.answer))
        }
    }

    func testSpellingQuestionHasNoOptionsAndSpeaksNothing() throws {
        try makeWords(count: 8, learned: true)
        let quiz = QuizService.makeQuiz(from: allWords(), count: 8, seed: 3)
        let spelling = try XCTUnwrap(quiz.first { $0.kind == .spelling })

        XCTAssertTrue(spelling.options.isEmpty)
        XCTAssertNil(spelling.spokenText)
        XCTAssertEqual(spelling.prompt, spelling.meaning)
        XCTAssertFalse(spelling.answer.isEmpty)
    }

    func testListeningQuestionCarriesSpokenWord() throws {
        try makeWords(count: 8, learned: true)
        let quiz = QuizService.makeQuiz(from: allWords(), count: 10, seed: 5)
        let listening = try XCTUnwrap(quiz.first { $0.kind == .listening })

        XCTAssertNotNil(listening.spokenText)
        XCTAssertFalse(listening.spokenText!.isEmpty)
    }

    // MARK: - 判分

    func testIsCorrectIgnoresCaseAndWhitespace() throws {
        let question = QuizQuestion(kind: .spelling,
                                    wordID: UUID(),
                                    prompt: "放弃",
                                    options: [],
                                    answer: "Abandon",
                                    meaning: "放弃")
        XCTAssertTrue(QuizService.isCorrect("  abandon \n", for: question))
        XCTAssertTrue(QuizService.isCorrect("ABANDON", for: question))
        XCTAssertFalse(QuizService.isCorrect("abandan", for: question))
    }

    func testKindCycleIsStable() {
        XCTAssertEqual(QuizService.kind(for: 0), .meaning)
        XCTAssertEqual(QuizService.kind(for: 3), .meaning)
        XCTAssertEqual(QuizService.kind(for: 4), .spelling)
        XCTAssertEqual(QuizService.kind(for: 6), .spelling)
        XCTAssertEqual(QuizService.kind(for: 7), .listening)
        XCTAssertEqual(QuizService.kind(for: 9), .listening)
        XCTAssertEqual(QuizService.kind(for: 10), .meaning)
    }

    // MARK: - 辅助

    private func allWords() -> [Word] {
        (try? context.fetch(FetchDescriptor<Word>())) ?? []
    }

    private func makeWords(count: Int, learned: Bool) throws {
        let deck = Deck(name: "测试词库", summary: "", sortIndex: 0)
        context.insert(deck)
        for index in 0..<count {
            let word = Word(deckID: deck.id,
                            word: "word\(index)",
                            meaning: "释义\(index)",
                            sortIndex: index)
            context.insert(word)
            if learned {
                let state = ReviewState(wordID: word.id,
                                        deckID: deck.id,
                                        repetitions: 1,
                                        dueDate: Date())
                context.insert(state)
                word.reviewState = state
            }
            deck.words.append(word)
        }
        try context.save()
    }
}