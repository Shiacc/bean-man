import Foundation
import Observation

/// 小豆洞察的「展示状态」：dismiss 冷却、每天最多几条。
///
/// 引擎（`InsightEngine`）只负责算出洞察；能不能给用户看，由这里决定——
/// 这样「知道了」的冷却可以单测，不用把状态塞进 View。
@MainActor
@Observable
final class InsightCenter {

    static let shared = InsightCenter()

    /// `kind.rawValue` → 上次 dismiss 的时刻
    private(set) var dismissedAt: [String: Date] = [:]

    /// dismiss 后 7 天不再主动弹（PRD §5.14.5）
    static let cooldown: TimeInterval = 7 * 24 * 60 * 60
    /// 每天最多几条（PRD AC-66）
    static let dailyLimit = 3

    private let defaults: UserDefaults
    private let prefix = "insight.dismissed."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    private func load() {
        var map: [String: Date] = [:]
        for kind in Insight.Kind.allCases {
            let value = defaults.double(forKey: prefix + kind.rawValue)
            guard value > 0 else { continue }
            map[kind.rawValue] = Date(timeIntervalSince1970: value)
        }
        dismissedAt = map
    }

    // MARK: - 查询

    func isDismissed(_ kind: Insight.Kind, now: Date = Date()) -> Bool {
        guard let at = dismissedAt[kind.rawValue] else { return false }
        return now.timeIntervalSince(at) < Self.cooldown
    }

    /// 真正可以展示的洞察：去掉冷却中的、一天最多 `dailyLimit` 条。
    func visible(_ insights: [Insight],
                 now: Date = Date(),
                 limit: Int = InsightCenter.dailyLimit) -> [Insight] {
        Array(insights.filter { !isDismissed($0.kind, now: now) }.prefix(max(0, limit)))
    }

    // MARK: - 变更

    /// 返回是否真的记了一次（重复 dismiss 不刷新冷却，避免一直点一直续命）。
    @discardableResult
    func dismiss(_ kind: Insight.Kind, now: Date = Date()) -> Bool {
        guard !isDismissed(kind, now: now) else { return false }
        dismissedAt[kind.rawValue] = now
        defaults.set(now.timeIntervalSince1970, forKey: prefix + kind.rawValue)
        return true
    }

    func resetAll() {
        for kind in Insight.Kind.allCases {
            defaults.removeObject(forKey: prefix + kind.rawValue)
        }
        dismissedAt = [:]
    }
}