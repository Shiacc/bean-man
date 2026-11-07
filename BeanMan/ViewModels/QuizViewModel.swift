import Foundation
import SwiftData
import Observation

/// 测试流程的状态机。和复习算法完全隔离：测试只记成绩，不改到期时间（PRD F7）。
@MainActor
@Observable
final class QuizViewModel {

    private(set) var questions: [QuizQuestion] = []
    private(set) var index = 0
    private(set) var results: [Bool] = []
    private(set) var isAnswered = false
    private(set) var lastWasCorrect = false
    private(set) var finished = false
    private(set) var startedAt = Date()
    private(set) var errorMessage: String?
    /// 拼写题答错写回错词本的次数（成绩页提示用）
    private(set) var wrongCount = 0

    /// 选择题已选中的选项；拼写题的输入框
    var selectedOption: String?
    var typedAnswer = ""

    var current: QuizQuestion? {
        questions.indices.contains(index) ? questions[index] : nil
    }

    var total: Int { questions.count }
    var correctCount: Int { results.filter { $0 }.count }
    var progress: Double {
        total == 0 ? 0 : Double(index + (isAnswered ? 1 : 0)) / Double(total)
    }
    var positionText: String { total == 0 ? "0 / 0" : "\(index + 1) / \(total)" }
    var accuracy: Double { results.isEmpty ? 0 : Double(correctCount) / Double(results.count) }
    var accuracyText: String { "\(Int((accuracy * 100).rounded()))%" }

    var canSubmit: Bool {
        guard let current, !isAnswered else { return false }
        if current.kind == .spelling {
            return !typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return selectedOption != nil
    }

    var hasEnoughWords: Bool { !questions.isEmpty }

    var resultText: String {
        switch accuracy {
        case 0.9...:    return "很稳，这批词基本都会了"
        case 0.7..<0.9: return "不错，错的几个正好该复习"
        case 0.4..<0.7: return "一半左右，回去把错词过一遍"
        default:        return "有点难，先专注错词本吧"
        }
    }

    // MARK: - 开始 / 结束

    func start(context: ModelContext, count: Int = QuizService.defaultCount) {
        let deck = try? StudyRepository.currentDeck(context: context)
        let words = deck?.words ?? []
        questions = QuizService.makeQuiz(from: words, count: count)
        index = 0
        results = []
        isAnswered = false
        lastWasCorrect = false
        finished = false
        selectedOption = nil
        typedAnswer = ""
        startedAt = Date()
        errorMessage = nil
    }

    // MARK: - 答题

    func choose(_ option: String) {
        guard !isAnswered, let current, current.kind != .spelling else { return }
        selectedOption = option
        evaluate(option, question: current)
    }

    func submitTyped(context: ModelContext) {
        guard !isAnswered, let current, current.kind == .spelling else { return }
        let correct = QuizService.isCorrect(typedAnswer, for: current)
        evaluate(typedAnswer, question: current)

        // 拼写错了才写回：等同一次「不认识」，直接进错词本（PRD §5.7.1）。
        // 选择题/听音题有 25% 猜中率，写回会冤枉算法，所以不写。
        if !correct {
            writeBackAsWrong(question: current, context: context)
        }
    }

    private func writeBackAsWrong(question: QuizQuestion, context: ModelContext) {
        guard let word = (try? context.fetch(FetchDescriptor<Word>()))
            .first(where: { $0.id == question.wordID }) else { return }

        let item = QueueItem(id: word.id, word: word, isNew: word.reviewState == nil)
        do {
            _ = try StudyRepository.apply(rating: .again, to: item, context: context)
            wrongCount += 1
        } catch {
            errorMessage = "记录错词失败"
        }
    }

    private func evaluate(_ input: String, question: QuizQuestion) {
        let correct = QuizService.isCorrect(input, for: question)
        lastWasCorrect = correct
        results.append(correct)
        isAnswered = true
    }

    func next(context: ModelContext) {
        guard isAnswered else { return }
        if index + 1 < questions.count {
            index += 1
            isAnswered = false
            lastWasCorrect = false
            selectedOption = nil
            typedAnswer = ""
        } else {
            finish(context: context)
        }
    }

    private func finish(context: ModelContext) {
        finished = true
        guard !questions.isEmpty else { return }

        let now = Date()
        let session = StudySession(kind: "quiz",
                                   startedAt: startedAt,
                                   endedAt: now,
                                   dayKey: DayKey.string(for: now),
                                   newWordCount: 0,
                                   reviewCount: 0,
                                   answeredCount: results.count,
                                   correctCount: correctCount)
        context.insert(session)
        try? context.save()
    }

    func restart(context: ModelContext) {
        start(context: context)
    }
}