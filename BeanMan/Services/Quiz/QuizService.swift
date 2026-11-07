import Foundation

/// 题型。PRD F7：看单词选释义、看释义拼写、听音选词。
enum QuizKind: String, CaseIterable, Identifiable {
    case meaning
    case spelling
    case listening

    var id: String { rawValue }

    var title: String {
        switch self {
        case .meaning:   return "看词选义"
        case .spelling:  return "看义拼词"
        case .listening: return "听音选义"
        }
    }
}

/// 一道题。纯值类型，不引用 SwiftData 对象 —— 抽题可以在单测里跑。
struct QuizQuestion: Identifiable, Equatable {
    let id: UUID
    let kind: QuizKind
    let wordID: UUID
    /// 题干：选择题是单词本身，拼写题是释义
    let prompt: String
    /// 选项（拼写题为空）
    let options: [String]
    /// 正确答案（选项文本 / 单词拼写）
    let answer: String
    /// 答错时展示的释义
    let meaning: String
    /// 听音题要朗读的内容
    let spokenText: String?

    init(id: UUID = UUID(),
         kind: QuizKind,
         wordID: UUID,
         prompt: String,
         options: [String],
         answer: String,
         meaning: String,
         spokenText: String? = nil) {
        self.id = id
        self.kind = kind
        self.wordID = wordID
        self.prompt = prompt
        self.options = options
        self.answer = answer
        self.meaning = meaning
        self.spokenText = spokenText
    }
}

/// 抽题规则：
/// - 只从「学过的词」里抽（有 ReviewState）；
/// - 至少 4 个词才出题，否则返回空，界面上引导先去学；
/// - 10 道题按 4:3:3 分配三种题型；词不够就少出题，不重复。
enum QuizService {

    static let defaultCount = 10

    static func makeQuiz(from words: [Word],
                         count: Int = defaultCount,
                         seed: UInt64? = nil) -> [QuizQuestion] {
        let learned = words.filter { $0.reviewState != nil && !$0.meaning.isEmpty }
        guard learned.count >= 4 else { return [] }

        var generator = SeededGenerator(seed: seed ?? UInt64(Date().timeIntervalSince1970))
        let pool = learned.shuffled(using: &generator)
        let limit = min(count, pool.count)

        var questions: [QuizQuestion] = []

        for index in 0..<limit {
            let word = pool[index]
            let kind = kind(for: index)
            let others = pool.filter { $0.id != word.id }

            switch kind {
            case .meaning:
                guard let question = meaningQuestion(word: word, others: others, using: &generator) else { continue }
                questions.append(question)
            case .listening:
                guard let question = listeningQuestion(word: word, others: others, using: &generator) else { continue }
                questions.append(question)
            case .spelling:
                questions.append(QuizQuestion(kind: .spelling,
                                              wordID: word.id,
                                              prompt: word.meaning,
                                              options: [],
                                              answer: word.word,
                                              meaning: word.meaning))
            }
        }

        return questions
    }

    /// 前 4 道看词选义，接着 3 道拼写，最后 3 道听音；超过 10 道循环。
    static func kind(for index: Int) -> QuizKind {
        switch index % 10 {
        case 0..<4: return .meaning
        case 4..<7: return .spelling
        default:    return .listening
        }
    }

    private static func meaningQuestion(word: Word,
                                        others: [Word],
                                        using generator: inout SeededGenerator) -> QuizQuestion? {
        let distractors = others
            .filter { $0.meaning != word.meaning }
            .shuffled(using: &generator)
            .prefix(3)
            .map(\.meaning)
        guard distractors.count == 3 else { return nil }

        let options = (distractors + [word.meaning]).shuffled(using: &generator)
        return QuizQuestion(kind: .meaning,
                            wordID: word.id,
                            prompt: word.word,
                            options: options,
                            answer: word.meaning,
                            meaning: word.meaning)
    }

    private static func listeningQuestion(word: Word,
                                          others: [Word],
                                          using generator: inout SeededGenerator) -> QuizQuestion? {
        let distractors = others
            .filter { $0.meaning != word.meaning }
            .shuffled(using: &generator)
            .prefix(3)
            .map(\.meaning)
        guard distractors.count == 3 else { return nil }

        let options = (distractors + [word.meaning]).shuffled(using: &generator)
        return QuizQuestion(kind: .listening,
                            wordID: word.id,
                            prompt: "听发音，选出正确释义",
                            options: options,
                            answer: word.meaning,
                            meaning: word.meaning,
                            spokenText: word.word)
    }

    /// 判分：忽略大小写与首尾空格；拼写题容忍多余空格。
    static func isCorrect(_ input: String, for question: QuizQuestion) -> Bool {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let answer = question.answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == answer
    }
}

/// 可复现的伪随机源 —— 测试里传同一个 seed 就能拿到同一套题。
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}