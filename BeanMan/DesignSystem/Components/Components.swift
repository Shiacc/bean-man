import SwiftUI

// MARK: - 小豆气泡卡

/// 今日页顶部的小豆卡。对应 Figma `xiaodou`。
struct XiaodouCard: View {
    let line: String
    let detail: String?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("豆")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.Palette.brandTint)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.Palette.brand))

            VStack(alignment: .leading, spacing: 6) {
                Text(line)
                    .font(Theme.Font.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(Theme.Font.bodySmall)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Palette.brandTint)
        )
    }
}

// MARK: - 统计小卡

/// 今日页 / 完成页的三连统计卡。
struct StatTile: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
            Text(value)
                .font(Theme.Font.statNumber)
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.system(size: 10))
                .foregroundStyle(Theme.Palette.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .frame(height: 96, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                .fill(Theme.Palette.surface)
        )
    }
}

// MARK: - 按钮

/// 主按钮（品牌色实心）。
struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.button)
            .foregroundStyle(Theme.Palette.bg)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(enabled ? (configuration.isPressed ? Theme.Palette.brandPressed : Theme.Palette.brand)
                                  : Theme.Palette.surfaceAlt)
            )
            .opacity(enabled ? 1 : 0.6)
    }
}

/// 次按钮（白底描边）。
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.button)
            .foregroundStyle(Theme.Palette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(configuration.isPressed ? Theme.Palette.surface : Theme.Palette.bg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )
    }
}

// MARK: - 进度条

struct ProgressTrack: View {
    var progress: Double          // 0...1
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.surfaceAlt)
                Capsule()
                    .fill(Theme.Palette.brand)
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - 四档评分

/// 对应 Figma 组件 `DS/Rating/*`。四个按钮等宽铺满一行。
struct RatingBar: View {
    var onRate: (Rating) -> Void

    private func tint(_ rating: Rating) -> (fg: Color, bg: Color) {
        switch rating {
        case .again: return (Theme.Palette.danger, Theme.Palette.dangerTint)
        case .hard:  return (Theme.Palette.warning, Theme.Palette.warningTint)
        case .good:  return (Theme.Palette.success, Theme.Palette.successTint)
        case .easy:  return (Theme.Palette.brand, Theme.Palette.brandTint)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Rating.allCases) { rating in
                let c = tint(rating)
                Button {
                    onRate(rating)
                } label: {
                    Text(rating.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(c.fg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.rating, style: .continuous)
                                .fill(c.bg)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(rating.title))
            }
        }
    }
}

// MARK: - 快捷行

/// 「再复习 5 个错词」这类列表行。
struct ActionRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Palette.brand)
                    .frame(width: 24)
                Text(title)
                    .font(Theme.Font.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.Palette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                    .fill(Theme.Palette.bg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}