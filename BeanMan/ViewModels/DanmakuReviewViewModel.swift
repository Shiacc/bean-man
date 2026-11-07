import Foundation
import Observation
import SwiftData
import SwiftUI

/// 弹幕复习（片尾字幕式滚动）的状态。
///
/// 这里只管「滚到哪儿、多快、什么主题」，不碰 SwiftUI —— 视图用 `elapsed(at:)`
/// 从时间线反推偏移，所以暂停/继续不需要任何计时器，天然不会漂。
@MainActor
@Observable
final class DanmakuReviewViewModel {

    /// 一条字幕：单词 + 音标 + 词性 + 释义
    struct Line: Identifiable, Equatable {
        let id: UUID
        let word: String
        let phonetic: String
        let partOfSpeech: String
        let meaning: String
    }

    enum Theme: String, CaseIterable, Identifiable {
        case dark
        case light

        var id: String { rawValue }

        var title: String { self == .dark ? "深色" : "浅色" }

        /// 全屏背景
        var background: Color {
            self == .dark ? Color(hex: 0x1C1B18) : Color(hex: 0xF7F5F1)
        }

        /// 单词
        var primary: Color {
            self == .dark ? Color(hex: 0xFFF1E8) : Color(hex: 0x1C1B18)
        }

        /// 音标 / 词性
        var tertiary: Color {
            self == .dark ? Color(hex: 0x8A8478) : Color(hex: 0xA39D93)
        }

        /// 释义
        var secondary: Color {
            self == .dark ? Color(hex: 0xC9C3B7) : Color(hex: 0x6E6962)
        }

        var next: Theme { self == .dark ? .light : .dark }
    }

    /// 0.5× / 1× / 1.5× / 2×
    static let speedOptions: [Double] = [0.5, 1.0, 1.5, 2.0]

    private(set) var lines: [Line] = []
    private(set) var theme: Theme = .dark
    private(set) var speed: Double = 1.0
    private(set) var isPaused = false
    private(set) var errorMessage: String?

    /// 已经滚过的秒数（不含当前这段）
    private var accumulated: Double = 0
    /// 当前这段的开始时刻（nil = 暂停中）
    private var resumedAt: Date?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 每秒滚多少点（1× 速度）
    static let basePointsPerSecond: Double = 34
    /// 每块字幕的高度（竖屏两行 / 横屏一行），用于循环取模
    static let blockHeight: Double = 74

    // MARK: - 加载

    func load(context: ModelContext, now: Date = Date()) {
        do {
            guard let deck = try StudyRepository.currentDeck(context: context) else {
                lines = []
                errorMessage = "还没有词库"
                return
            }

            // 优先学过的词（有复习状态），按到期时间升序；没学过就退回全部
            let all = deck.words.sorted { $0.sortIndex < $1.sortIndex }
            let learned = all
                .filter { $0.reviewState != nil }
                .sorted { ($0.reviewState?.dueDate ?? now) < ($1.reviewState?.dueDate ?? now) }
            let source = learned.isEmpty ? all : learned

            lines = source.map {
                Line(id: $0.id,
                     word: $0.word,
                     phonetic: $0.phonetic,
                     partOfSpeech: $0.partOfSpeech,
                     meaning: $0.meaning)
            }
            errorMessage = lines.isEmpty ? "这个词库还没有词" : nil
            restorePosition()
        } catch {
            lines = []
            errorMessage = "读取词库失败"
        }
    }

    /// 测试 / 预览用：直接灌字幕，跳过取库。
    func load(lines: [Line]) {
        self.lines = lines
        errorMessage = lines.isEmpty ? "没有可以滚的词" : nil
        restorePosition()
    }

    /// 测试用：把时钟拨到指定起点（resumedAt 为 nil 表示暂停）。
    func seek(accumulated: Double, resumedAt: Date?) {
        self.accumulated = max(0, accumulated)
        self.resumedAt = resumedAt
        self.isPaused = (resumedAt == nil)
    }

    // MARK: - 滚动时钟

    /// 从时间线时刻反推已滚秒数 —— 暂停时不再增长。
    func elapsed(at date: Date) -> Double {
        guard let resumedAt else { return accumulated }
        return accumulated + max(0, date.timeIntervalSince(resumedAt))
    }

    func pointsPerSecond(for speed: Double) -> Double {
        Self.basePointsPerSecond * speed
    }

    var pointsPerSecond: Double { pointsPerSecond(for: speed) }

    /// 滚动偏移（已对内容总高取模，实现无缝循环）。
    func offset(at date: Date) -> Double {
        guard !lines.isEmpty else { return 0 }
        let total = Double(lines.count) * Self.blockHeight
        guard total > 0 else { return 0 }
        let raw = elapsed(at: date) * pointsPerSecond
        return raw.truncatingRemainder(dividingBy: total)
    }

    /// 进度 0...1（按已滚过的圈内位置算，仅用于视觉反馈）。
    func progress(at date: Date) -> Double {
        guard !lines.isEmpty else { return 0 }
        let total = Double(lines.count) * Self.blockHeight
        return min(1, max(0, offset(at: date) / total))
    }

    // MARK: - 交互

    func togglePause(now: Date = Date()) {
        if isPaused {
            resumedAt = now
        } else {
            accumulated = elapsed(at: now)
            resumedAt = nil
        }
        isPaused.toggle()
        savePosition()
    }

    func setSpeed(_ value: Double) {
        // 换速前把已滚时间结算掉，避免速度突变时位置跳一下
        accumulated = elapsed(at: Date())
        resumedAt = isPaused ? nil : Date()
        speed = value
    }

    func toggleTheme() {
        theme = theme.next
    }

    var speedText: String {
        speed == floor(speed) ? "\(Int(speed))×" : "\(speed)×"
    }

    // MARK: - 记住位置（按词库存秒数）

    private var positionKey: String { "danmaku.position.v1" }
    private var hintKey: String { "danmaku.hintShown.v1" }

    func restorePosition() {
        let saved = defaults.double(forKey: positionKey)
        accumulated = max(0, saved)
        resumedAt = Date()
        isPaused = false
    }

    func savePosition() {
        defaults.set(accumulated, forKey: positionKey)
    }

    /// 首次进入才提示「← 右滑退出」
    var shouldShowExitHint: Bool {
        !defaults.bool(forKey: hintKey)
    }

    func markExitHintShown() {
        defaults.set(true, forKey: hintKey)
    }
}