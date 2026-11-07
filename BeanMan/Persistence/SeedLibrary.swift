import Foundation
import SwiftData

/// 内置示例词库。
///
/// 版权说明（务必遵守）：这里的单词、释义、例句全部自己写，
/// 不使用任何商业词库（如某某词典、某某词书）的内容，也不含真题语料。
/// 只收录「高频、结构简单、可以自写例句」的词，够点完一轮卡片即可。
enum SeedLibrary {

    struct Entry {
        let word: String
        let phonetic: String
        let pos: String
        let meaning: String
        let example: String
        let translation: String
        let tags: String
    }

    static let name = "示例词库 · 豆卡 24 词"
    static let summary = "内置的 24 个高频词，用来试手感"

    static let entries: [Entry] = [
        .init(word: "abandon", phonetic: "/əˈbændən/", pos: "v.", meaning: "放弃；抛弃；遗弃",
              example: "He abandoned the plan at the last minute.",
              translation: "他在最后一刻放弃了这个计划。", tags: "高频"),
        .init(word: "benefit", phonetic: "/ˈbenɪfɪt/", pos: "n./v.", meaning: "好处；受益",
              example: "Both sides benefit from the deal.",
              translation: "双方都能从这笔交易中受益。", tags: "高频"),
        .init(word: "confident", phonetic: "/ˈkɒnfɪdənt/", pos: "adj.", meaning: "自信的；有把握的",
              example: "She felt confident before the interview.",
              translation: "面试前她感觉很有把握。", tags: "情绪"),
        .init(word: "decide", phonetic: "/dɪˈsaɪd/", pos: "v.", meaning: "决定；下决心",
              example: "We decided to walk instead of driving.",
              translation: "我们决定走路去，不开车。", tags: "高频"),
        .init(word: "effort", phonetic: "/ˈefət/", pos: "n.", meaning: "努力；费力的事",
              example: "It took a lot of effort to finish the report.",
              translation: "写完这份报告费了很大劲。", tags: "高频"),
        .init(word: "familiar", phonetic: "/fəˈmɪliə/", pos: "adj.", meaning: "熟悉的；常见的",
              example: "The street looks familiar to me.",
              translation: "这条街我看着眼熟。", tags: "描述"),
        .init(word: "gather", phonetic: "/ˈɡæðə/", pos: "v.", meaning: "收集；聚集",
              example: "They gathered leaves in the yard.",
              translation: "他们在院子里收集落叶。", tags: "动作"),
        .init(word: "hesitate", phonetic: "/ˈhezɪteɪt/", pos: "v.", meaning: "犹豫；迟疑",
              example: "Don't hesitate to ask questions.",
              translation: "有问题尽管问，别犹豫。", tags: "动作"),
        .init(word: "improve", phonetic: "/ɪmˈpruːv/", pos: "v.", meaning: "改进；提高",
              example: "Reading every day improves your vocabulary.",
              translation: "每天阅读能提高词汇量。", tags: "高频"),
        .init(word: "journey", phonetic: "/ˈdʒɜːni/", pos: "n.", meaning: "旅程；行程",
              example: "The journey took about six hours.",
              translation: "这趟行程花了大约六个小时。", tags: "名词"),
        .init(word: "kindness", phonetic: "/ˈkaɪndnəs/", pos: "n.", meaning: "善意；善举",
              example: "Thank you for your kindness.",
              translation: "谢谢你的好意。", tags: "情绪"),
        .init(word: "limit", phonetic: "/ˈlɪmɪt/", pos: "n./v.", meaning: "限制；限度",
              example: "There is a limit to how much I can carry.",
              translation: "我能拿的东西是有限度的。", tags: "名词"),
        .init(word: "mention", phonetic: "/ˈmenʃn/", pos: "v.", meaning: "提到；说起",
              example: "She mentioned your name at the meeting.",
              translation: "她在会上提到了你的名字。", tags: "动作"),
        .init(word: "notice", phonetic: "/ˈnəʊtɪs/", pos: "v./n.", meaning: "注意到；通知",
              example: "I didn't notice the sign on the door.",
              translation: "我没注意到门上的告示。", tags: "高频"),
        .init(word: "obvious", phonetic: "/ˈɒbviəs/", pos: "adj.", meaning: "明显的；显而易见的",
              example: "The answer seems obvious now.",
              translation: "现在这个答案看起来很明显。", tags: "描述"),
        .init(word: "patient", phonetic: "/ˈpeɪʃnt/", pos: "adj./n.", meaning: "有耐心的；病人",
              example: "Be patient with yourself while learning.",
              translation: "学习的时候对自己耐心一点。", tags: "情绪"),
        .init(word: "quiet", phonetic: "/ˈkwaɪət/", pos: "adj.", meaning: "安静的；清静的",
              example: "The library is quiet in the morning.",
              translation: "图书馆早上很安静。", tags: "描述"),
        .init(word: "reason", phonetic: "/ˈriːzn/", pos: "n.", meaning: "原因；理由",
              example: "Is there a reason you're late?",
              translation: "你迟到有什么原因吗？", tags: "高频"),
        .init(word: "suggest", phonetic: "/səˈdʒest/", pos: "v.", meaning: "建议；暗示",
              example: "I suggest we start early tomorrow.",
              translation: "我建议我们明天早点开始。", tags: "动作"),
        .init(word: "tidy", phonetic: "/ˈtaɪdi/", pos: "adj./v.", meaning: "整洁的；整理",
              example: "Please keep your desk tidy.",
              translation: "请保持桌面整洁。", tags: "描述"),
        .init(word: "unusual", phonetic: "/ʌnˈjuːʒuəl/", pos: "adj.", meaning: "不寻常的；特别的",
              example: "It was an unusual day for everyone.",
              translation: "对大家来说那是特别的一天。", tags: "描述"),
        .init(word: "value", phonetic: "/ˈvæljuː/", pos: "n./v.", meaning: "价值；重视",
              example: "She values honest feedback.",
              translation: "她看重坦诚的反馈。", tags: "高频"),
        .init(word: "wonder", phonetic: "/ˈwʌndə/", pos: "v./n.", meaning: "想知道；惊奇",
              example: "I wonder what he meant by that.",
              translation: "我想知道他那么说是什么意思。", tags: "动作"),
        .init(word: "yesterday", phonetic: "/ˈjestədeɪ/", pos: "n./adv.", meaning: "昨天",
              example: "Yesterday was warmer than today.",
              translation: "昨天比今天暖和。", tags: "时间")
    ]

    /// 把示例词库装进数据库（幂等：已有内置词库就直接返回）。
    @discardableResult
    static func installIfNeeded(in context: ModelContext) throws -> Deck? {
        let decks = try context.fetch(FetchDescriptor<Deck>())
        if let existing = decks.first(where: { $0.isBuiltIn }) { return existing }

        let deck = Deck(name: name, summary: summary, isBuiltIn: true, sortIndex: 0)
        context.insert(deck)

        for (index, entry) in entries.enumerated() {
            let word = Word(deckID: deck.id,
                            word: entry.word,
                            phonetic: entry.phonetic,
                            partOfSpeech: entry.pos,
                            meaning: entry.meaning,
                            example: entry.example,
                            exampleTranslation: entry.translation,
                            tagsRaw: entry.tags,
                            sortIndex: index)
            word.deck = deck
            context.insert(word)
        }

        let settings = try AppSettingsStore.current(in: context)
        if settings.selectedDeckID == nil {
            settings.selectedDeckID = deck.id
        }
        try context.save()
        return deck
    }
}