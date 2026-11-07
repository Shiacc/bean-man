import Foundation
import Observation
import SwiftData

/// 一次学习会话的状态机：建队列 → 翻面 → 评分 → 下一张 → 完成。
@MainActor
@Observable
final class StudyViewModel {

    enum Kind: String {
        case today
        case wrongBook
    }

    private(set) var queue: [QueueItem] = []
    private(set) var index: Int = 0
    private(set) var finished = false
    private(set) var started = false
    private(set) var correctCount = 0
    private(set) var answeredCount = 0
    private(set) var lastOutcome: SRSOutcome?

    var isFlipped = false
    var errorMessage: String?

    private var session: StudySession?
    private var startedAt = Date()

    var current: QueueItem? {
        guard index >= 0, index < queue.count else { return nil }
        return queue[index]
    }

    var progress: Double {
        guard !queue.isEmpty else { return 0 }
        return Double(index) / Double(queue.count)
    }

    /// 「3 / 20」这种位置文案。
    var positionText: String {
        guard !queue.isEmpty else { return "0 / 0" }
        return "\(min(index + 1, queue.count)) / \(queue.count)"
    }

    var accuracyText: String {
        guard answeredCount > 0 else { return "—" }
        let value = Int((Double(correctCount) / Double(answeredCount) * 100).rounded())
        return "\(value)%"
    }

    var elapsedText: String {
        let seconds = max(0, Int(Date().timeIntervalSince(startedAt)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - 生命周期

    func start(context: ModelContext, items: [QueueItem]? = nil) {
        guard !started else { return }
        started = true
        startedAt = Date()
        do {
            if let items {
                queue = items
            } else {
                queue = try StudyRepository.buildQueue(context: context)
            }
        } catch {
            queue = []
            errorMessage = "没能生成今日任务，请稍后再试"
        }
        let session = StudySession(kind: "today",
                                   startedAt: startedAt,
                                   dayKey: DayKey.string(for: startedAt))
        context.insert(session)
        self.session = session
        finished = queue.isEmpty
        index = 0
        isFlipped = false
    }

    func flip() {
        guard current != nil else { return }
        isFlipped.toggle()
    }

    /// 评分并进入下一张。返回是否还有下一张。
    @discardableResult
    func rate(_ rating: Rating, context: ModelContext) -> Bool {
        guard let item = current else { return false }

        do {
            let outcome = try StudyRepository.apply(rating: rating,
                                                   to: item,
                                                   context: context,
                                                   session: session)
            lastOutcome = outcome
            answeredCount += 1
            if rating.isCorrect { correctCount += 1 }
        } catch {
            errorMessage = "记录失败：\(error.localizedDescription)"
        }

        advance()
        return !finished
    }

    private func advance() {
        isFlipped = false
        index += 1
        if index >= queue.count {
            finished = true
            closeSession()
        }
    }

    private func closeSession() {
        guard let session else { return }
        session.endedAt = Date()
        // 统计数字已在 apply 里累加，这里只补一个结束时间
    }

    /// 完成页用的数字。
    var summary: (answered: Int, correct: Int, accuracy: Int) {
        let accuracy = answeredCount == 0 ? 0 : Int((Double(correctCount) / Double(answeredCount) * 100).rounded())
        return (answeredCount, correctCount, accuracy)
    }
}