import Foundation
import Observation

/// 一条提示的声明。提示本身不做任何 UI，只描述「想说什么」和「什么时候允许说」。
struct HintRequest: Identifiable, Hashable {
    let id: String
    /// 数字越大越优先。高优先级正在显示时，低优先级会被让路。
    var priority: Int = 0
    /// 整个安装周期只显示一次（默认）。关掉可做「每次都要提示」的强引导。
    var onceOnly: Bool = true
    /// 同一提示两次显示的最短间隔（秒）。0 表示不限制。
    var cooldown: TimeInterval = 0
}

/// 一次请求的判定结果。做成独立枚举便于单测断言。
enum HintDecision: Equatable {
    case show
    case skipOnce          // 已经看过
    case skipCooldown      // 冷却中
    case skipBusy          // 有更高优先级的正在显示
}

/// 纯逻辑：只依赖「看过哪些 / 上次什么时候看过 / 当前正在显示什么」。
/// 不碰 SwiftUI、不碰文件系统，方便 XCTest。
struct HintScheduler {
    var seen: Set<String> = []
    var lastShown: [String: Date] = [:]

    mutating func decide(_ request: HintRequest, current: HintRequest?, now: Date) -> HintDecision {
        if request.onceOnly, seen.contains(request.id) {
            return .skipOnce
        }
        if request.cooldown > 0, let last = lastShown[request.id],
           now.timeIntervalSince(last) < request.cooldown {
            return .skipCooldown
        }
        if let current, current.id != request.id, current.priority > request.priority {
            return .skipBusy
        }
        return .show
    }

    mutating func markShown(_ request: HintRequest, now: Date) {
        seen.insert(request.id)
        lastShown[request.id] = now
    }
}

/// 全局提示中心。视图只读 `current`，由它决定「现在该不该弹」。
@MainActor
@Observable
final class HintCenter {
    static let shared = HintCenter()

    /// 当前正在显示的提示；nil 表示没有。
    private(set) var current: HintRequest?

    private var scheduler = HintScheduler()
    private let defaults: UserDefaults

    private enum Key {
        static let seen = "hint.seen.v1"
        static let lastShown = "hint.lastShown.v1"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let ids = defaults.array(forKey: Key.seen) as? [String] {
            scheduler.seen = Set(ids)
        }
        if let raw = defaults.dictionary(forKey: Key.lastShown) {
            var parsed: [String: Date] = [:]
            for (id, value) in raw {
                if let seconds = (value as? NSNumber)?.doubleValue {
                    parsed[id] = Date(timeIntervalSince1970: seconds)
                }
            }
            scheduler.lastShown = parsed
        }
    }

    /// 请求显示一条提示。返回判定结果，方便调用方打日志或做后续动作。
    @discardableResult
    func request(_ request: HintRequest, now: Date = Date()) -> HintDecision {
        let decision = scheduler.decide(request, current: current, now: now)
        guard decision == .show else { return decision }
        scheduler.markShown(request, now: now)
        persist()
        current = request
        return .show
    }

    func dismiss() {
        current = nil
    }

    /// 开发用：清空所有记录，让提示从头再来。
    func resetAll() {
        scheduler = HintScheduler()
        current = nil
        defaults.removeObject(forKey: Key.seen)
        defaults.removeObject(forKey: Key.lastShown)
    }

    func hasSeen(_ id: String) -> Bool {
        scheduler.seen.contains(id)
    }

    private func persist() {
        defaults.set(Array(scheduler.seen), forKey: Key.seen)
        var raw: [String: Double] = [:]
        for (id, date) in scheduler.lastShown {
            raw[id] = date.timeIntervalSince1970
        }
        defaults.set(raw, forKey: Key.lastShown)
    }
}

// MARK: - 提示文案与 id

/// 提示的 id 常量，避免各处手写字符串写错。
enum HintID {
    static let todayStartStudy = "today.startStudy"
    static let todayStatTiles = "today.statTiles"
    static let studyFlipCard = "study.flipCard"
    static let studyRateButtons = "study.rateButtons"
}

/// 每个 id 对应的文案。写在一起方便统一口径（小豆口吻、≤22 字）。
struct HintCopy {
    var title: String
    var message: String
    var actionTitle: String

    static func of(_ id: String) -> HintCopy {
        switch id {
        case HintID.todayStartStudy:
            return HintCopy(
                title: "从这里开始",
                message: "点一下就开始今天的学习，先清到期的，再学新词。",
                actionTitle: "知道了"
            )
        case HintID.todayStatTiles:
            return HintCopy(
                title: "三个数字",
                message: "今天学了多少、正确率、连续几天，都在这儿。",
                actionTitle: "知道了"
            )
        case HintID.studyFlipCard:
            return HintCopy(
                title: "点卡片翻面",
                message: "先自己回想意思，再翻面看答案，记得更牢。",
                actionTitle: "知道了"
            )
        case HintID.studyRateButtons:
            return HintCopy(
                title: "选一个真实的感受",
                message: "别怕选「不认识」，选得准，下次安排得更合适。",
                actionTitle: "知道了"
            )
        default:
            return HintCopy(title: "提示", message: "", actionTitle: "知道了")
        }
    }

    /// 默认请求：一次性、普通优先级。
    static func request(_ id: String, priority: Int = 10) -> HintRequest {
        HintRequest(id: id, priority: priority, onceOnly: true)
    }
}