import SwiftUI

/// 气泡的语气。颜色全部取自 `Theme.Palette`，不新增色值。
enum BubbleTone {
    case neutral   // 说明、解释
    case brand     // 小豆说话（默认）
    case success   // 答对、完成
    case warning   // 要提醒一下
    case danger    // 错了、要注意

    var fill: Color {
        switch self {
        case .neutral: Theme.Palette.surface
        case .brand: Theme.Palette.brandTint
        case .success: Theme.Palette.successTint
        case .warning: Theme.Palette.warningTint
        case .danger: Theme.Palette.dangerTint
        }
    }

    var accent: Color {
        switch self {
        case .neutral: Theme.Palette.textSecondary
        case .brand: Theme.Palette.brand
        case .success: Theme.Palette.success
        case .warning: Theme.Palette.warning
        case .danger: Theme.Palette.danger
        }
    }
}

/// 小尾巴指向哪一侧（指向谁）。
enum BubbleEdge {
    case leading
    case trailing
    case top
    case bottom
}

/// 对话气泡。
///
/// 做法：圆角矩形 + 一个 45° 旋转的小方块当尾巴，两者同色、无描边、只留很淡的投影。
/// 这样尾巴与主体的接缝天然看不见（不用手写带尾巴的 Path，少一类几何 bug）。
struct SpeechBubble<Content: View>: View {
    var tone: BubbleTone = .brand
    var edge: BubbleEdge = .leading
    /// 尾巴沿边的位置（0…1），默认居中偏上
    var tailPosition: CGFloat = 0.32
    /// 气泡最大宽度，nil 表示跟随父级
    var maxWidth: CGFloat? = 300
    var onTap: (() -> Void)?

    @ViewBuilder var content: Content

    private let tailSize: CGFloat = 16
    private let radius: CGFloat = 18

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .background(background)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .onTapGesture { onTap?() }
    }

    private var background: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                tail(in: geo.size)
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tone.fill)
            }
        }
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    @ViewBuilder
    private func tail(in size: CGSize) -> some View {
        let half = tailSize / 2
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(tone.fill)
            .frame(width: tailSize, height: tailSize)
            .rotationEffect(.degrees(45))
            .position(tailCenter(in: size, half: half))
    }

    private func tailCenter(in size: CGSize, half: CGFloat) -> CGPoint {
        switch edge {
        case .leading:
            return CGPoint(x: 0, y: size.height * tailPosition)
        case .trailing:
            return CGPoint(x: size.width, y: size.height * tailPosition)
        case .top:
            return CGPoint(x: size.width * tailPosition, y: 0)
        case .bottom:
            return CGPoint(x: size.width * tailPosition, y: size.height)
        }
    }
}

// MARK: - 常用组合：小豆说话

/// 带签名的气泡正文 —— 动物给表情，气泡里签「小豆」，责任分明。
struct XiaodouSpeech: View {
    var line: String
    var detail: String?
    var tone: BubbleTone = .brand
    var edge: BubbleEdge = .leading
    var onTap: (() -> Void)?

    var body: some View {
        SpeechBubble(tone: tone, edge: edge, onTap: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text("小豆")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tone.accent.opacity(0.85))
                Text(line)
                    .font(Theme.Font.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(Theme.Font.bodySmall)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

#Preview("气泡 · 五种语气") {
    ScrollView {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(Theme.Palette.brand).frame(width: 40, height: 40)
                XiaodouSpeech(line: "12 个到期词，先清一波？", detail: "先清到期，再学 20 个新词")
            }
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(Theme.Palette.success).frame(width: 40, height: 40)
                XiaodouSpeech(line: "这个记住了", tone: .success)
            }
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(Theme.Palette.warning).frame(width: 40, height: 40)
                XiaodouSpeech(line: "还有 20 个没看，别急", tone: .warning)
            }
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(Theme.Palette.danger).frame(width: 40, height: 40)
                XiaodouSpeech(line: "这个已经错了三次，要不要记一下", tone: .danger)
            }
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(Theme.Palette.textSecondary).frame(width: 40, height: 40)
                XiaodouSpeech(line: "长按词条可以收藏", tone: .neutral)
            }
            // 右对齐的尾巴
            HStack {
                Spacer()
                XiaodouSpeech(line: "我在右边说话", edge: .trailing)
                Circle().fill(Theme.Palette.surfaceAlt).frame(width: 40, height: 40)
            }
        }
        .padding(20)
    }
    .background(Theme.Palette.bg)
}