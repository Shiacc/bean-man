import Foundation

/// 免费版的额度。数值只在这里定义一次，UI 与导入/建库都引用它。
enum FreeTier {
    /// 免费版能建几个自建词库（内置示例库不计入）
    static let deckLimit = 1
    /// 免费版所有词条总数上限
    static let wordLimit = 500
    /// 免费版每日新词上限
    static let dailyNewLimit = 20
}

/// 额度的纯函数判定（不碰 SwiftData、不碰 StoreKit，方便单测）。
enum TierGate {

    /// 今日新词额度：免费版封顶 20，买断后按用户设置。
    static func maxDailyNew(isPro: Bool, requested: Int) -> Int {
        isPro ? max(0, requested) : min(max(0, requested), FreeTier.dailyNewLimit)
    }

    /// 还能建几个自建词库。
    static func remainingDeckSlots(existingCustomDecks: Int, isPro: Bool) -> Int {
        if isPro { return Int.max }
        return max(0, FreeTier.deckLimit - existingCustomDecks)
    }

    static func canCreateDeck(existingCustomDecks: Int, isPro: Bool) -> Bool {
        remainingDeckSlots(existingCustomDecks: existingCustomDecks, isPro: isPro) > 0
    }

    /// 还能导入多少词条。
    static func remainingWordSlots(currentWordCount: Int, isPro: Bool) -> Int {
        if isPro { return Int.max }
        return max(0, FreeTier.wordLimit - currentWordCount)
    }

    /// 把「想导入的数量」压到额度内。
    static func allowedWordCount(requested: Int, currentWordCount: Int, isPro: Bool) -> Int {
        min(max(0, requested), remainingWordSlots(currentWordCount: currentWordCount, isPro: isPro))
    }

    static func canAddWords(currentWordCount: Int, adding: Int, isPro: Bool) -> Bool {
        allowedWordCount(requested: adding, currentWordCount: currentWordCount, isPro: isPro) > 0
    }

    /// 免费额度是否已经用满（用于设置页显示状态）。
    static func isAtLimit(currentWordCount: Int, customDecks: Int, isPro: Bool) -> Bool {
        guard !isPro else { return false }
        return currentWordCount >= FreeTier.wordLimit || customDecks >= FreeTier.deckLimit
    }
}

/// 为什么会看到付费墙。文案统一在这里，避免各处自己编。
enum UpgradeReason: String, Identifiable, CaseIterable {
    case deckLimit
    case wordLimit
    case dailyNewLimit
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deckLimit: return "自建词库已到 1 个"
        case .wordLimit: return "词条已到 500 个"
        case .dailyNewLimit: return "每日新词上限 20 个"
        case .manual: return "解锁全部功能"
        }
    }

    var message: String {
        switch self {
        case .deckLimit:
            return "免费版可以建 1 个自己的词库。解锁后可以无限建库，也能分别管理。"
        case .wordLimit:
            return "免费版最多 500 个词条。解锁后不限词条数，导入大词库不会再被截断。"
        case .dailyNewLimit:
            return "免费版每天最多学 20 个新词。解锁后按你自己设的额度来。"
        case .manual:
            return "一次买断，永久可用。没有订阅、没有广告、不收集数据。"
        }
    }
}