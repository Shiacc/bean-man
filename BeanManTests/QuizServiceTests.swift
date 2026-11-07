import XCTest
import SwiftData
@testable import BeanMan

/// 抽题与判分的单测。PRD F7：不碰复习算法，只出题、只判分。
@MainActor
final class QuizServiceTests: XCTestCase {

    private var container: ModelContainer!

    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try BeanManStore.makeContainer(inMemory: true)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - 辅助

    /// 造 n 个词；learned = true 时给每个词建 ReviewState（只有学过的词才可能被抽到）。
    @discardableResult
    private func makeWords(_ count: Int, learned: Bool = true) throws -> [Word] {
        let deck = Deck(name: "测试词库", summary: "", sortIndex: 0)
        context.insert(deck)

        var words: [Word] = []
        for index in 0..<count {
            let word = Word(deckID: deck.id,
                            word: "word\(index)",
                            meaning: "释义\(index)")
            context.insert(word)
            deck.words.append(word)

            if learned {
                let state = ReviewState(wordID: word.id,
                                        deckID: deck.id,
                                        repetitions: 2,
                                        dueDate: Date())
                context.insert(state)
                word.reviewState = state
            }
            words.append(word)
        }
        try context.save()
        return words
    }

    // MARK: - 抽题

    func testNeedsAtLeastFourLearnedWords() throws {
        let words = try makeWords(3)
        XCTAssertTrue(QuizService.makeQuiz(from: words).isEmpty)
    }

    func testIgnoresWordsWithoutReviewState() throws {
        // 3 个学过 + 5 个没学过，仍然不够 4 个，应该出不了题
        let learned = try makeWords(3)
        let fresh = try makeWords(5, learned: false)
        XCTAssertTrue(QuizService.makeQuiz(from: learned + fresh).isEmpty)
    }

    func testKindDistributionIsFourThreeThree() throws {
        let words = try makeWords(12)
        let questions = QuizService.makeQuiz(from: words, count: 10, seed: 42)
        XCTAssertEqual(questions.count, 10)

        let meanings = questions.filter { $0.kind == .meaning }.count
        let spellings = questions.filter { $0.kind == .spelling }.count
        let listenings = questions.filter { $0.kind == .listening }.count
        XCTAssertEqual(meanings, 4)
        XCTAssertEqual(spellings, 3)
        XCTAssertEqual(listenings, 3)
    }

    func testQuestionCountIsCappedByPoolSize() throws {
        let words = try makeWords(6)
        let questions = QuizService.makeQuiz(from: words, count: 10, seed: 7)
        XCTAssertEqual(questions.count, 6, "词不够时少出题，不重复")
    }

    func testWordIDsAreUnique() throws {
        let words = try makeWords(12)
        let questions = QuizService.makeQuiz(from: words, count: 10, seed: 99)
        XCTAssertEqual(Set(questions.map(\.wordID)).count, questions.count)
    }

    func testChoiceQuestionsHaveFourUniqueOptionsIncludingAnswer() throws {
        let words = try makeWords(12)
        let questions = QuizService.makeQuiz(from: words, count: 10, seed: 3)
            .filter { $0.kind != .spelling }

        XCTAssertFalse(questions.isEmpty)
        for question in questions {
            XCTAssertEqual(question.options.count, 4, "\(question.kind) 应该是四选一")
            XCTAssertEqual(Set(question.options).count, 4, "选项不能重复")
            XCTAssertTrue(question.options.contains(question.answer), "正确答案必须在选项里")
        }
    }

    func testSpellingQuestionHasNoOptionsAndUsesMeaningAsPrompt() throws {
        let words = try makeWords(12)
        let questions = QuizService.makeQuiz(from: words, count: 10, seed: 5)
            .filter { $0.kind == .spelling }

        XCTAssertFalse(questions.isEmpty)
        for question in questions {
            XCTAssertTrue(question.options.isEmpty)
            XCTAssertEqual(question.prompt, question.meaning)
        }
    }

    func testListeningQuestionCarriesSpokenText() throws {
        let words = try makeWords(12)
        let questions = QuizService.makeQuiz(from: words, count: 10, seed: 11)
            .filter { $0.kind == .listening }

        XCTAssertFalse(questions.isEmpty)
        for question in questions {
            let word = try XCTUnwrap(words.first { $0.id == question.wordID })
            XCTAssertEqual(question.spokenText, word.word)
        }
    }

    func testSameSeedProducesSameQuiz() throws {
        let words = try makeWords(12)
        let first = QuizService.makeQuiz(from: words, count: 10, seed: 2024)
        let second = QuizService.makeQuiz(from: words, count: 10, seed: 2024)

        XCTAssertEqual(first.map(\.wordID), second.map(\.wordID))
        XCTAssertEqual(first.map(\.answer), second.map(\.answer))
        XCTAssertEqual(first.map(\.kind), second.map(\.kind))
    }

    // MARK: - 判分

    func testIsCorrectIgnoresCaseAndSurroundingSpaces() throws {
        let question = QuizQuestion(kind: .spelling,
                                    wordID: UUID(),
                                    prompt: "放弃",
                                    options: [],
                                    answer: "Abandon",
                                    meaning: "放弃")

        XCTAssertTrue(QuizService.isCorrect("abandon", for: question))
        XCTAssertTrue(QuizService.isCorrect("  ABANDON  ", for: question))
        XCTAssertFalse(QuizService.isCorrect("abandan", for: question))
        XCTAssertTrue(QuizService.isCorrect("abandon ", for: question), "尾部空格应被忽略")
    }
}