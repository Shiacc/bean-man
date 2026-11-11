import Foundation
import Observation
import SwiftData

/// 一次学习会话的状态机：建队列 → 翻面 → 评分 → 下一张 → 完成。
@MainActor
@Observable
final class StudyViewModel {

    /// 这次会话是什么类型：今日任务 / 错词本专项复习。
    private(set) var kind: StudyKind = .today

    private(set) var queue: [QueueItem] = []
    private(set) var index: Int = 0
    private(set) var finished = false
    private(set) var started = false
    private(set) var correctCount = 0
    private(set) var answeredCount = 0
    /// 跳过了几张（轻点已翻面 / 上滑），不写记录、不算分。
    private(set) var skippedCount = 0
    private(set) var lastOutcome: SRSOutcome?

    var isFlipped = false
    var errorMessage: String?

    private var session: StudySession?
    private var startedAt = Date()

    // MARK: - 撤销上一张

    /// 上一张评分前，Word 的 ReviewState 长什么样（用来撤回）。
    private struct UndoState {
        let wordID: UUID
        let wasNew: Bool
        let easeFactor: Double
        let intervalDays: Int
        let repetitions: Int
        let dueDate: Date
        let lastReviewedAt: Date?
        let lapses: Int
        let phase: StudyPhase
        let lastRatingRaw: Int?
        let wrongBookHiddenAt: Date?
    }

    private var undoState: UndoState?
    private var undoRecord: StudyRecord?
    private(set) var canUndo = false
    private(set) var undoHint: String?

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

    func start(context: ModelContext,
               kind: StudyKind = .today,
               items: [QueueItem]? = nil) {
        guard !started else { return }
        started = true
        self.kind = kind
        startedAt = Date()
        do {
            if let items {
                queue = items
            } else {
                let configured = (try? AppSettingsStore.settings(in: context))?.dailyNewLimit ?? 20
                let limit = TierGate.maxDailyNew(isPro: PurchaseService.shared.isPro,
                                                 requested: configured)
                queue = try StudyRepository.buildQueue(context: context, newLimitOverride: limit)
            }
        } catch {
            queue = []
            errorMessage = "没能生成今日任务，请稍后再试"
        }
        let session = StudySession(kind: kind.rawValue,
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

    /// 跳过当前这张：不动记忆曲线、不写 `StudyRecord`，只把位置往前挪。
    ///
    /// 轻点已翻面的卡片、上滑都走这里（PRD §5.3.1）。
    /// 跳过不产生记录，所以也不该给「撤销」——撤销只回滚真评过的那一张。
    func skip() {
        guard current != nil else { return }
        skippedCount += 1
        canUndo = false
        undoState = nil
        undoRecord = nil
        undoHint = nil
        advance()
    }

    /// 评分并进入下一张。返回是否还有下一张。
    @discardableResult
    func rate(_ rating: Rating, context: ModelContext) -> Bool {
        guard let item = current else { return false }

        // 评分前留一份快照，供「撤销」使用
        snapshotForUndo(item)

        do {
            let outcome = try StudyRepository.apply(rating: rating,
                                                   to: item,
                                                   context: context,
                                                   session: session)
            lastOutcome = outcome
            answeredCount += 1
            if rating.isCorrect { correctCount += 1 }
            undoRecord = session?.records.max(by: { $0.reviewedAt < $1.reviewedAt })
            canUndo = true
            undoHint = rating.needsReviewList ? "记到错词本了" : nil
        } catch {
            errorMessage = "记录失败：\(error.localizedDescription)"
            canUndo = false
        }

        advance()
        return !finished
    }

    /// 撤回上一张：把复习状态还原、删掉那条记录、退回上一张。
    func undo(context: ModelContext) {
        guard canUndo, let state = undoState else { return }

        // 先记下这次评分是否算对，再删记录（删完就取不到了）
        let wasCorrect = undoRecord?.rating.isCorrect ?? false

        do {
            if let newRecord = undoRecord {
                context.delete(newRecord)
            }

            if let reviewState = try? context.fetch(FetchDescriptor<ReviewState>())
                .first(where: { $0.wordID == state.wordID }) {

                if state.wasNew {
                    // 新词第一次评分 → 回到「没有复习状态」
                    context.delete(reviewState)
                } else {
                    reviewState.easeFactor = state.easeFactor
                    reviewState.intervalDays = state.intervalDays
                    reviewState.repetitions = state.repetitions
                    reviewState.dueDate = state.dueDate
                    reviewState.lastReviewedAt = state.lastReviewedAt
                    reviewState.lapses = state.lapses
                    reviewState.phaseRaw = state.phase.rawValue
                    reviewState.lastRatingRaw = state.lastRatingRaw
                    reviewState.wrongBookHiddenAt = state.wrongBookHiddenAt
                }
            }

            try context.save()
        } catch {
            errorMessage = "撤销失败：\(error.localizedDescription)"
            return
        }

        // 计数与位置回退
        answeredCount = max(0, answeredCount - 1)
        if wasCorrect { correctCount = max(0, correctCount - 1) }
        if let session {
            session.answeredCount = max(0, session.answeredCount - 1)
            session.correctCount = correctCount
        }

        index = max(0, index - 1)
        isFlipped = true
        finished = false
        canUndo = false
        undoState = nil
        undoRecord = nil
        undoHint = nil
    }

    private func snapshotForUndo(_ item: QueueItem) {
        undoState = nil
        let word = item.word
        if let state = word.reviewState {
            undoState = UndoState(wordID: word.id,
                                  wasNew: false,
                                  easeFactor: state.easeFactor,
                                  intervalDays: state.intervalDays,
                                  repetitions: state.repetitions,
                                  dueDate: state.dueDate,
                                  lastReviewedAt: state.lastReviewedAt,
                                  lapses: state.lapses,
                                  phase: state.phase,
                                  lastRatingRaw: state.lastRatingRaw,
                                  wrongBookHiddenAt: state.wrongBookHiddenAt)
        } else {
            undoState = UndoState(wordID: word.id,
                                  wasNew: true,
                                  easeFactor: 2.5,
                                  intervalDays: 0,
                                  repetitions: 0,
                                  dueDate: Date(),
                                  lastReviewedAt: nil,
                                  lapses: 0,
                                  phase: .new,
                                  lastRatingRaw: nil,
                                  wrongBookHiddenAt: nil)
        }
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