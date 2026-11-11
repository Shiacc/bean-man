import SwiftUI

/// 把某个视图在指定坐标系里的位置报上来，供引导挖洞用。
struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    /// 记录自身位置。用 `.onPreferenceChange(FramePreferenceKey.self)` 收。
    func captureFrame(_ id: String, in space: CoordinateSpace = .global) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: FramePreferenceKey.self,
                    value: [id: geo.frame(in: space)]
                )
            }
        )
    }
}

/// 引导蒙层：压暗全屏、在目标处挖一个圆角洞、画脉冲环，并在目标上方或下方放一句说明。
///
/// 用法：
/// ```swift
/// .overlay {
///     if let hint = hintCenter.current, let frame = frames[hint.id] {
///         HintOverlay(target: frame, copy: HintCopy.of(hint.id)) { hintCenter.dismiss() }
///     }
/// }
/// ```
struct HintOverlay: View {
    var target: CGRect
    var copy: HintCopy
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    /// 读屏焦点：引导出现时直接落在说明标题上（AC-49）
    @AccessibilityFocusState private var bubbleFocused: Bool

    private let holePadding: CGFloat = 8
    private let holeRadius: CGFloat = 18

    init(target: CGRect, copy: HintCopy, onDismiss: @escaping () -> Void) {
        self.target = target
        self.copy = copy
        self.onDismiss = onDismiss
    }

    var body: some View {
        GeometryReader { geo in
            // target 是用 `.global` 坐标系量出来的；overlay 可能挂在屏幕里任意位置，
            // 所以先换算成本地坐标再挖洞，避免蒙层整体偏移一个安全区的高度。
            let origin = geo.frame(in: .global).origin
            let hole = target
                .offsetBy(dx: -origin.x, dy: -origin.y)
                .insetBy(dx: -holePadding, dy: -holePadding)
            let showBelow = hole.maxY < geo.size.height * 0.58

            ZStack(alignment: .topLeading) {
                dimLayer(hole: hole)

                RoundedRectangle(cornerRadius: holeRadius, style: .continuous)
                    .stroke(Theme.Palette.brand, lineWidth: 2)
                    .frame(width: hole.width, height: hole.height)
                    .scaleEffect(pulse ? 1.06 : 1.0)
                    .opacity(pulse ? 0.35 : 1.0)
                    .position(x: hole.midX, y: hole.midY)
                    .allowsHitTesting(false)

                tapPointer(hole: hole)

                bubbleStack(hole: hole, showBelow: showBelow, screenHeight: geo.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        // 蒙层是模态的：读屏时焦点不跑到下面的页面里去
        .accessibilityAddTraits(.isModal)
        .task {
            // 等蒙层挂上无障碍树再抢焦点，否则会被系统忽略
            try? await Task.sleep(nanoseconds: 600_000_000)
            bubbleFocused = true
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: 压暗 + 挖洞

    private func dimLayer(hole: CGRect) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.42))
            RoundedRectangle(cornerRadius: holeRadius, style: .continuous)
                .frame(width: hole.width, height: hole.height)
                .position(x: hole.midX, y: hole.midY)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    // MARK: 手指

    @ViewBuilder
    private func tapPointer(hole: CGRect) -> some View {
        Image(systemName: "hand.tap.fill")
            .font(.system(size: 30))
            .foregroundStyle(Theme.Palette.brand)
            .shadow(color: Color.black.opacity(0.2), radius: 6, y: 3)
            // 手指放在目标右下角，别压住按钮文字
            .position(x: hole.maxX - 26, y: hole.midY + 4)
            .offset(y: pulse ? -6 : 0)
            .opacity(reduceMotion ? 0.9 : 1.0)
            .allowsHitTesting(false)
    }

    // MARK: 说明气泡

    private func bubbleStack(hole: CGRect, showBelow: Bool, screenHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            if showBelow {
                Spacer(minLength: 0).frame(height: hole.maxY + 18)
                bubble(edge: .top)
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                bubble(edge: .bottom)
                Spacer(minLength: 0).frame(height: max(0, screenHeight - hole.minY + 18))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.screenH)
    }

    private func bubble(edge: BubbleEdge) -> some View {
        SpeechBubble(tone: .brand, edge: edge, tailPosition: 0.5, maxWidth: 320) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(copy.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .accessibilityFocused($bubbleFocused)
                        .accessibilityAddTraits(.isHeader)
                    if !copy.message.isEmpty {
                        Text(copy.message)
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button(action: onDismiss) {
                    Text(copy.actionTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.brand)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview("引导 · 挖洞") {
    ZStack {
        VStack(spacing: 20) {
            Text("今日")
                .font(Theme.Font.screenTitle)
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.Palette.brand)
                .frame(height: 52)
                .overlay(Text("开始学习").foregroundStyle(.white))
            Spacer()
        }
        .padding(20)

        HintOverlay(
            target: CGRect(x: 20, y: 96, width: 350, height: 52),
            copy: HintCopy.of(HintID.todayStartStudy)
        ) {}
    }
    .background(Theme.Palette.bg)
}