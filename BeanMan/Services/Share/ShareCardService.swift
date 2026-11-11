import Foundation
import SwiftUI
import UIKit

// MARK: - 内容

/// 分享卡上的一格数字。
struct ShareCardStat: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let unit: String
}

/// 分享卡的全部文案与数字。
///
/// 单独抽出来是为了能单测：版式会一直改，但「分享什么」应该有确定答案。
struct ShareCardContent: Equatable {
    /// 顶部小字
    var kicker: String
    /// 主标题（连续打卡天数）
    var headline: String
    var subtitle: String
    /// 三格数字
    var stats: [ShareCardStat]
    var quote: String
    var dateText: String
    var watermark: String

    /// 从今日页的数字里拼出一张卡。
    ///
    /// - Parameters:
    ///   - streak: 连续打卡天数
    ///   - learnedToday: 今天已经学过的词数
    ///   - learnedWords: 累计学过（有复习状态）的词数
    ///   - dueToday: 今天还剩的到期词数；为 0 且今天学过 → 「今天的账清了」
    static func make(streak: Int,
                     learnedToday: Int,
                     learnedWords: Int,
                     dueToday: Int,
                     now: Date = Date(),
                     calendar: Calendar = .current) -> ShareCardContent {
        let safeStreak = max(0, streak)
        let safeToday = max(0, learnedToday)
        let safeLearned = max(0, learnedWords)
        let safeDue = max(0, dueToday)

        let headline: String
        switch safeStreak {
        case 0: headline = "今天开始"
        case 1: headline = "打卡第 1 天"
        default: headline = "坚持了 \(safeStreak) 天"
        }

        let subtitle: String
        if safeStreak >= 7 {
            subtitle = "一周了，别断"
        } else if safeStreak >= 1 {
            subtitle = "每天一点，比一次背很多有用"
        } else {
            subtitle = "第一个词，开始了"
        }

        let quote: String
        if safeDue == 0 && safeToday > 0 {
            quote = "今天的账清了"
        } else if safeToday > 0 {
            quote = "今天记住一个也算赢"
        } else {
            quote = "慢慢来，比一次背很多有用"
        }

        return ShareCardContent(
            kicker: "豆卡单词 · 打卡",
            headline: headline,
            subtitle: subtitle,
            stats: [
                ShareCardStat(id: "streak", label: "连续打卡", value: "\(safeStreak)", unit: "天"),
                ShareCardStat(id: "today", label: "今日已学", value: "\(safeToday)", unit: "个"),
                ShareCardStat(id: "total", label: "累计学过", value: "\(safeLearned)", unit: "词")
            ],
            quote: quote,
            dateText: dateText(now: now, calendar: calendar),
            watermark: "BeanMan · 豆卡单词"
        )
    }

    /// 「2026 年 11 月 11 日」
    static func dateText(now: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy 年 M 月 d 日"
        return formatter.string(from: now)
    }
}

// MARK: - 规格

/// 分享图规格：3 倍图正好 1080 × 1350（4:5）。
///
/// 尺寸写在代码里而不是靠截图工具裁，这样「导出的图一定是 1080×1350」是可断言的。
enum ShareCardSpec {
    static let pointSize = CGSize(width: 360, height: 450)
    static let scale: CGFloat = 3

    static var pixelSize: CGSize {
        CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
    }
}

// MARK: - 渲染

/// 把分享卡画成图片。
///
/// 用 `ImageRenderer` 本地渲染：不联网、不上传、不需要账号（PRD §5.16 / AC-80）。
@MainActor
enum ShareCardRenderer {

    static func image(for content: ShareCardContent) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(content: content))
        renderer.scale = ShareCardSpec.scale
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// 渲染并写进临时目录，返回图片与可分享的 PNG 地址；失败返回 nil。
    static func makeShareFile(for content: ShareCardContent,
                              now: Date = Date()) -> (image: UIImage, url: URL)? {
        guard let rendered = image(for: content), let data = rendered.pngData() else { return nil }

        let name = "BeanMan-checkin-\(DayKey.string(for: now)).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return (rendered, url)
        } catch {
            return nil
        }
    }
}