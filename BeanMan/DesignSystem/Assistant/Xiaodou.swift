import Foundation

/// 小豆出现的时机。纯本地文案，不联网、不接大模型（D3 决策）。
enum XiaodouMoment {
    case todayHasWork(due: Int, new: Int)
    case todayDone(streak: Int)
    case todayEmpty
    case cardFront
    case cardBack
    case sessionDone(accuracy: Int, streak: Int)
    case wrongBook(count: Int)
}

/// 小豆的台词。
///
/// 文案规范（D3）：
/// - 口语、短句，每条 ≤ 22 个汉字；最多一个感叹号。
/// - 不叫用户「主人」，不卖萌过度，只做「提醒 + 安抚 + 报数」三件事。
/// - **不要加「小豆小豆」**：那是语音唤醒词，等以后真的做语音唤醒再用；
///   现在纯文字气泡里念出来像在自言自语，签名（气泡上的「小豆」）已经足够。
enum Xiaodou {

    /// 主句。
    static func line(_ moment: XiaodouMoment) -> String {
        switch moment {
        case let .todayHasWork(due, new):
            if due == 0 && new > 0 { return "今天有 \(new) 个新词" }
            if new == 0 { return "\(due) 个到期词在等你" }
            return "\(due) 个到期词，先清一波？"

        case let .todayDone(streak):
            return "今天的词都过完了"

        case .todayEmpty:
            return "今天没有要背的词，休息一下"

        case .cardFront:
            return "先读一遍再翻面"

        case .cardBack:
            return "记得住就选「认识」"

        case .sessionDone:
            return "这一轮过完了"

        case let .wrongBook(count):
            return "错词本有 \(count) 个词"
        }
    }

    /// 第二行补充说明，可为空。
    static func detail(_ moment: XiaodouMoment) -> String? {
        switch moment {
        case let .todayHasWork(due, new):
            if due == 0 { return "先学新词，到期词明天再来" }
            if new == 0 { return "清完到期就能收工" }
            return "先清到期，再学 \(new) 个新词"

        case let .todayDone(streak):
            return streak > 1 ? "连续打卡 \(streak) 天，明天见" : "明天见"

        case .todayEmpty:
            return "明天会有新的到期词"

        case .cardFront:
            return "不确定就点发音听一遍"

        case .cardBack:
            return "模糊也算过，会被记进错词本"

        case let .sessionDone(accuracy, streak):
            return "正确率 \(accuracy)% · 连续 \(streak) 天"

        case let .wrongBook(count):
            return count > 5 ? "挑 5 个先过一遍" : "正好一口气过完"
        }
    }

    /// 鼓励语（测试页、空状态用），随机取一条。
    static func encouragement(seed: Int) -> String {
        let lines = [
            "慢慢来，比一次背很多更有用",
            "今天记住一个也算赢",
            "记不住的词，多见面几次就熟了",
            "先把到期清掉，心里就轻了"
        ]
        guard !lines.isEmpty else { return "" }
        return lines[abs(seed) % lines.count]
    }
}