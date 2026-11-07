import Foundation
import SwiftData

/// 小豆的一条洞察。文案必须可解释、可执行——不能是「你很棒」这种废话。
struct Insight: Identifiable, Equatable {
    enum Kind: String {
        case bestHour
        case backlog
        case streakRisk
        case wrongWords
        case firstWeek
    }

    let id: String
    let kind: Kind
    let title: String
    let detail: String
    /// 有动作时给出按钮文案（今日页只展示，不强制）
    let actionTitle: String?
}

/// 一条「推荐今天学」的词。
struct WordRecommendation: Identifiable, Equatable {
    let id: UUID
    let word: String
    let reason: String
    let lapses: Int

    static func == (lhs: WordRecommendation, rhs: WordRecommendation) -> Bool {
        lhs.id == rhs.id && lhs.reason == rhs.reason
    }
}

struct InsightSnapshot: Equatable {
    var insights: [Insight] = []
    var recommendations: [WordRecommendation] = []
    var recommendedIDs: [UUID] { recommendations.map(\.id) }
    /// 推荐词里有几个今天其实不到期（这些是额外加进来的）
    var extraCount: Int = 0

    static let empty = InsightSnapshot()
}

/// 小豆的分析引擎：只读数据库，规则固定、可解释、可测试。
///
/// 设计约束：
/// - 推荐最多 3 个词，宁可少推也不刷屏；
/// - 只推进「已经学过、但错得多或拖得久」的词，不干扰新词计划；
/// - 每条洞察都要能对应一个具体动作（改提醒、清到期、复习错词）。
enum InsightEngine {

    static let recommendationLimit = 3

    static func snapshot(context: ModelContext,
                         now: Date = Date(),
                         calendar: Calendar = .current,
                         limit: Int = recommendationLimit) throws -> InsightSnapshot {

        guard let deck = try StudyRepository.currentDeck(context: context) else {
            return .empty
        }
        let deckID = deck.id

        let words = try context.fetch(
            FetchDescriptor<Word>(predicate: #Predicate<Word> { $0.deckID == deckID })
        )
        let states = try context.fetch(
            FetchDescriptor<ReviewState>(predicate: #Predicate<ReviewState> { $0.deckID == deckID })
        )
        let records = try context.fetch(
            FetchDescriptor<StudyRecord>(predicate: #Predicate<StudyRecord> { $0.deckID == deckID })
        )

        let startOfToday = calendar.startOfDay(for: now)
        var snapshot = InsightSnapshot()

        // 1. 时段洞察：按 4 个时段统计正确率，样本 < 10 不开口
        snapshot.insights.append(contentsOf: hourInsights(records: records, calendar: calendar))

        // 2. 积压：到期词太多
        let dueStates = states.filter { !$0.isSuspended && $0.dueDate <= startOfToday }
        if dueStates.count >= 40 {
            snapshot.insights.append(Insight(id: "backlog",
                                             kind: .backlog,
                                             title: "到期词积压 \(dueStates.count) 个",
                                             detail: "先把到期清掉再学新词，不然越滚越多。",
                                             actionTitle: "开始清到期"))
        } else if !dueStates.isEmpty {
            let oldest = dueStates.map(\.dueDate).min() ?? startOfToday
            let days = max(0, calendar.dateComponents([.day], from: oldest, to: startOfToday).day ?? 0)
            if days >= 3 {
                snapshot.insights.append(Insight(id: "overdue",
                                                 kind: .backlog,
                                                 title: "有词拖了 \(days) 天",
                                                 detail: "最早到期的那批还没动。今天复习优先。",
                                                 actionTitle: "去复习"))
            }
        }

        // 3. 连续打卡风险：今天还没学
        let dayKeys = try StudyRepository.studiedDayKeys(context: context)
        let streak = DayKey.streak(from: dayKeys, today: now, calendar: calendar)
        let studiedToday = dayKeys.contains(DayKey.string(for: now, calendar: calendar))
        if streak >= 2 && !studiedToday {
            snapshot.insights.append(Insight(id: "streakRisk",
                                             kind: .streakRisk,
                                             title: "连续 \(streak) 天，今天还没学",
                                             detail: "学一个词也算续上。别断在今天。",
                                             actionTitle: "学 1 个"))
        }

        // 4. 推荐：错得多、又不是今天到期的词（到期词本来就在队列里）
        let wordByID = Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })
        let dueIDs = Set(dueStates.map(\.wordID))

        let candidates = states
            .filter { !$0.isSuspended && !$0.isWrongBookHidden }
            .filter { $0.lapses > 0 && !dueIDs.contains($0.wordID) }
            .sorted { lhs, rhs in
                if lhs.lapses != rhs.lapses { return lhs.lapses > rhs.lapses }
                return lhs.dueDate < rhs.dueDate
            }

        var recommendations: [WordRecommendation] = []
        for state in candidates {
            guard recommendations.count < max(0, limit) else { break }
            guard let word = wordByID[state.wordID] else { continue }
            recommendations.append(WordRecommendation(id: word.id,
                                                      word: word.word,
                                                      reason: "错了 \(state.lapses) 次",
                                                      lapses: state.lapses))
        }
        snapshot.recommendations = recommendations
        snapshot.extraCount = recommendations.count

        if !recommendations.isEmpty {
            snapshot.insights.insert(Insight(id: "wrongWords",
                                             kind: .wrongWords,
                                             title: "今天多带 \(recommendations.count) 个错词",
                                             detail: "这几个错得最多，已经排进今天的学习队列。",
                                             actionTitle: nil), at: 0)
        }

        return snapshot
    }

    // MARK: - 时段

    /// 把一天切成 4 段：早 5–11、午 11–17、晚 17–23、夜 23–5。
    private static func bucket(of date: Date, calendar: Calendar) -> Int {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<11: return 0
        case 11..<17: return 1
        case 17..<23: return 2
        default: return 3
        }
    }

    private static let bucketNames = ["早上", "下午", "晚上", "深夜"]

    private static func hourInsights(records: [StudyRecord], calendar: Calendar) -> [Insight] {
        guard records.count >= 10 else { return [] }

        struct Tally { var total = 0; var correct = 0 }
        var tallies: [Int: Tally] = [:]
        for record in records {
            let index = bucket(of: record.reviewedAt, calendar: calendar)
            var tally = tallies[index] ?? Tally()
            tally.total += 1
            if record.rating.isCorrect { tally.correct += 1 }
            tallies[index] = tally
        }

        let ranked = tallies
            .filter { $0.value.total >= 5 }
            .map { (index: $0.key, accuracy: Double($0.value.correct) / Double($0.value.total), total: $0.value.total) }
            .sorted { $0.accuracy > $1.accuracy }

        guard let best = ranked.first else { return [] }
        let percent = Int((best.accuracy * 100).rounded())
        var insights: [Insight] = [
            Insight(id: "bestHour",
                    kind: .bestHour,
                    title: "你\(bucketNames[best.index])记得最牢",
                    detail: "这段时间正确率 \(percent)%，比其他时段高。",
                    actionTitle: "改提醒时间")
        ]

        // 最差时段明显更低时，再补一条（差距 ≥ 15 个百分点才说）
        if ranked.count >= 2, let worst = ranked.last, best.accuracy - worst.accuracy >= 0.15 {
            let worstPercent = Int((worst.accuracy * 100).rounded())
            insights.append(Insight(id: "worstHour",
                                    kind: .bestHour,
                                    title: "\(bucketNames[worst.index])状态一般",
                                    detail: "正确率 \(worstPercent)%，这个时段适合复习旧词，别塞新词。",
                                    actionTitle: nil))
        }
        return insights
    }
}