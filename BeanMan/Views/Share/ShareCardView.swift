import SwiftUI
import UIKit

// MARK: - 分享卡

/// 1080 × 1350 的打卡分享卡（4:5）。
///
/// 只画，不管导出——导出在 `ShareCardRenderer`。这样 Xcode Canvas 能直接看版式，
/// 不用跑一遍渲染流程。
@MainActor
struct ShareCardView: View {
    let content: ShareCardContent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Spacer(minLength: 12)

            hero
                .frame(maxWidth: .infinity, alignment: .center)

            Text(content.headline)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 12)

            Text(content.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 4)

            statsBlock
                .padding(.top, 16)

            Text("「\(content.quote)」")
                .font(.system(size: 12))
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.top, 12)

            Spacer(minLength: 10)

            footer
        }
        .padding(24)
        .frame(width: ShareCardSpec.pointSize.width,
               height: ShareCardSpec.pointSize.height,
               alignment: .topLeading)
        .background(background)
        .clipped()
    }

    /// 打卡卡画小动物，成就卡画徽章——同一版式，两种「主角」。
    @ViewBuilder
    private var hero: some View {
        if let symbol = content.symbol {
            ZStack {
                Circle()
                    .fill(Theme.Palette.brandTint)
                Circle()
                    .strokeBorder(Theme.Palette.brandSoft, lineWidth: 2)
                Image(systemName: symbol)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(Theme.Palette.brand)
            }
            .frame(width: 104, height: 104)
        } else {
            AnimalView(animal: .juzi, size: 104, expression: .happy, animated: false)
                .frame(width: 104, height: 104)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 11, weight: .semibold))
            Text(content.kicker)
                .font(.system(size: 11, weight: .semibold))
            Spacer(minLength: 8)
            Text(content.dateText)
                .font(.system(size: 10))
        }
        .foregroundStyle(Theme.Palette.brandPressed)
    }

    private var statsBlock: some View {
        HStack(spacing: 0) {
            ForEach(content.stats) { stat in
                VStack(spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(stat.value)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(stat.unit)
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                    Text(stat.label)
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Palette.bg.opacity(0.72))
        )
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Text(content.watermark)
                .font(.system(size: 10, weight: .semibold))
            Spacer(minLength: 0)
            Text("离线 · 无账号")
                .font(.system(size: 9))
        }
        .foregroundStyle(Theme.Palette.textTertiary)
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Theme.Palette.brandTint, Theme.Palette.bg],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
            Circle()
                .fill(Theme.Palette.brandSoft.opacity(0.4))
                .frame(width: 260, height: 260)
                .blur(radius: 46)
                .offset(x: 128, y: -168)
        }
    }
}

// MARK: - 分享面板

/// 预览 + 分享。
///
/// 图片在打开面板时一次性渲染好，预览显示的就是导出的那张（WYSIWYG），
/// 不会出现「预览好看、分享出去变形」。
@MainActor
struct ShareCardSheet: View {
    let content: ShareCardContent

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var shareURL: URL?
    @State private var failed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                preview

                if let shareURL {
                    ShareLink(item: shareURL) {
                        Label("分享图片", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else if failed {
                    Text("生成分享图失败，稍后再试")
                        .font(Theme.Font.bodySmall)
                        .foregroundStyle(Theme.Palette.danger)
                } else {
                    ProgressView()
                        .frame(height: 52)
                }

                Text("图片在这台手机上生成，不上传、不需要账号。")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.Palette.bg)
            .navigationTitle("分享打卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .task { render() }
    }

    private var preview: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Theme.Palette.surface
                    .overlay {
                        ProgressView()
                    }
                    .aspectRatio(4.0 / 5.0, contentMode: .fit)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(color: Theme.cardShadow, radius: 16, y: 8)
    }

    private func render() {
        guard let result = ShareCardRenderer.makeShareFile(for: content) else {
            failed = true
            return
        }
        image = result.image
        shareURL = result.url
    }
}

#Preview("打卡分享图") {
    ShareCardView(content: ShareCardContent.make(streak: 7,
                                                 learnedToday: 18,
                                                 learnedWords: 236,
                                                 dueToday: 0))
        .padding(24)
        .background(Theme.Palette.surface)
}