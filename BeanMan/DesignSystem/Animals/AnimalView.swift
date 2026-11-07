import SwiftUI
import UIKit

/// 统一的小动物展示组件。
///
/// 只做三件事：取图、眨眼、缺资源兜底。所有动物尺寸、对齐、无障碍走同一条路径，
/// 这样 20 只动物的视觉一致性不用靠人肉保证。
///
/// ```swift
/// AnimalView(animal: .juzi, size: 96)
/// AnimalView(animal: .juzi, size: 160, expression: .happy, animated: false)
/// ```
@MainActor
struct AnimalView: View {
    let animal: Animal
    var size: CGFloat = 96
    var expression: AnimalExpression = .normal
    /// 常态下自动眨眼（有 Blink 资源才生效）
    var animated: Bool = true
    /// 轻微呼吸缩放，用于「常驻陪伴」位置
    var breathe: Bool = false

    @State private var blinking = false
    @State private var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var showsBlink: Bool {
        animated && !reduceMotion && expression == .normal && animal.isAvailable(.blink)
    }

    private var scale: CGFloat {
        breathe && breathing && !reduceMotion ? 1.03 : 1.0
    }

    var body: some View {
        content
            .frame(width: size, height: size)
            .scaleEffect(scale, anchor: .bottom)
            .animation(.easeInOut(duration: 2.4), value: breathing)
            .accessibilityElement()
            .accessibilityLabel(Text("\(animal.displayName)，\(animal.role)"))
            .task(id: taskKey) { await runLoops() }
    }

    @ViewBuilder
    private var content: some View {
        if animal.isAvailable(expression) {
            ZStack {
                image(animal.assetName(for: expression))
                if showsBlink {
                    image(animal.assetName(for: .blink))
                        .opacity(blinking ? 1 : 0)
                        .animation(.linear(duration: 0.06), value: blinking)
                }
            }
        } else {
            placeholder
        }
    }

    private func image(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .interpolation(.high)
    }

    /// 素材没到位时的占位：主色圆底 + 爪印，保证布局不跳
    private var placeholder: some View {
        ZStack {
            Circle()
                .fill(animal.accent.opacity(0.16))
            Image(systemName: "pawprint.fill")
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(animal.accent.opacity(0.85))
        }
        .frame(width: size, height: size)
    }

    private var taskKey: String {
        "\(animal.rawValue)-\(expression.rawValue)-\(animated)-\(breathe)"
    }

    private func runLoops() async {
        guard animated || breathe else { return }

        if breathe {
            breathing = true
        }
        guard showsBlink else { return }

        while !Task.isCancelled {
            // 3–5 秒随机间隔，避免多只动物同频眨眼
            let pause = Double.random(in: 3.0...5.0)
            try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
            guard !Task.isCancelled else { break }
            blinking = true
            try? await Task.sleep(nanoseconds: 120_000_000)
            blinking = false
        }
    }
}

// MARK: - 组合件

/// 小动物 + 一句说明，用在空状态、完成页这类「一格内容」的位置
@MainActor
struct AnimalCard: View {
    let animal: Animal
    var title: String
    var message: String
    var expression: AnimalExpression = .normal
    var size: CGFloat = 88

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            AnimalView(animal: animal, size: size, expression: expression, breathe: true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Font.bodySmall.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(message)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
    }
}

#Preview("橘子 · 三态") {
    VStack(spacing: 24) {
        HStack(spacing: 24) {
            AnimalView(animal: .juzi, size: 96)
            AnimalView(animal: .juzi, size: 96, expression: .happy, animated: false)
            AnimalView(animal: .juzi, size: 96, expression: .blink, animated: false)
        }
        AnimalCard(animal: .juzi, title: "橘子", message: "今天还有 12 个到期词，先啃三个？")
        HStack(spacing: 20) {
            // 未落素材的动物走占位
            AnimalView(animal: .dango, size: 64)
            AnimalView(animal: .yunduo, size: 64)
            AnimalView(animal: .youzi, size: 64)
        }
    }
    .padding(24)
    .background(Theme.Palette.bg)
}