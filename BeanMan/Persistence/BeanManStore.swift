import Foundation
import SwiftData

/// 数据库入口：真机用磁盘库，预览/测试用内存库。
enum BeanManStore {

    /// 所有 @Model 类型。加模型时同步改这里，并升 `schemaVersion`。
    static let schemaTypes: [any PersistentModel.Type] = [
        Deck.self, Word.self, ReviewState.self, StudyRecord.self, StudySession.self, AppSettings.self
    ]

    static var schema: Schema { Schema(schemaTypes) }

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // 真机上如果 schema 变更导致老库打不开，先退回内存库保证 App 能起（数据不丢只是这次不写盘），
            // 并把错误暴露给上层，后续版本再补 MigrationPlan。
            assertionFailure("ModelContainer 创建失败：\(error)")
            let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }

    /// 启动时的数据准备：建设置单例、装示例词库。
    static func bootstrap(_ context: ModelContext) {
        do {
            try AppSettingsStore.current(in: context)
            try SeedLibrary.installIfNeeded(in: context)
        } catch {
            assertionFailure("bootstrap 失败：\(error)")
        }
    }

    /// 预览用：内存库 + 示例词库 + 一点「已学 / 到期 / 打卡」的演示数据，
    /// 让 SwiftUI Preview 里的今日页和 Figma 稿一模一样。
    static func makePreviewContainer() -> ModelContainer {
        let container = makeContainer(inMemory: true)
        let context = ModelContext(container)
        bootstrap(context)
        seedDemoProgress(context)
        return container
    }

    /// 在示例词库上铺一层演示进度：12 个今天到期、8 个今天已学、7 天连续打卡。
    static func seedDemoProgress(_ context: ModelContext) {
        do {
            let words = try context.fetch(FetchDescriptor<Word>(sortBy: [SortDescriptor(\.sortIndex)]))
            guard words.count >= 20 else { return }
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            // 前 12 个：今天到期（之前学过）
            for word in words.prefix(12) {
                let state = ReviewState(wordID: word.id,
                                        deckID: word.deckID,
                                        easeFactor: 2.5,
                                        intervalDays: 3,
                                        repetitions: 2,
                                        dueDate: today,
                                        lastReviewedAt: calendar.date(byAdding: .day, value: -3, to: today),
                                        lapses: 0,
                                        phase: .review)
                state.word = word
                word.reviewState = state
                context.insert(state)
            }

            // 接下来 8 个：今天刚学完（会话计数用）
            for word in words.dropFirst(12).prefix(8) {
                let state = ReviewState(wordID: word.id,
                                        deckID: word.deckID,
                                        easeFactor: 2.5,
                                        intervalDays: 1,
                                        repetitions: 1,
                                        dueDate: calendar.date(byAdding: .day, value: 1, to: today) ?? today,
                                        lastReviewedAt: Date(),
                                        lapses: 0,
                                        phase: .learning)
                state.word = word
                word.reviewState = state
                context.insert(state)
            }

            // 演示错词本：前 6 个词各错 1–3 次（最近一次判成不认识/模糊），其中 1 个演示「已移出」
            for (offset, word) in words.prefix(6).enumerated() {
                guard let state = word.reviewState else { continue }
                state.lapses = offset % 3 + 1
                state.lastRatingRaw = offset % 2 == 0 ? Rating.again.rawValue : Rating.hard.rawValue
                if offset == 5 {
                    state.wrongBookHiddenAt = today
                }
            }

            // 连续 7 天打卡
            for offset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
                let session = StudySession(startedAt: day,
                                           endedAt: day,
                                           dayKey: DayKey.string(for: day, calendar: calendar),
                                           newWordCount: offset == 0 ? 8 : 12,
                                           reviewCount: offset == 0 ? 12 : 10,
                                           answeredCount: offset == 0 ? 20 : 22,
                                           correctCount: offset == 0 ? 17 : 18)
                context.insert(session)
            }
            try context.save()
        } catch {
            assertionFailure("seedDemoProgress 失败：\(error)")
        }
    }
}