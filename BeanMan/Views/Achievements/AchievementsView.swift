import SwiftUI

/// 成就与里程碑 —— 对应 Figma `T-14-01 成就与里程碑`。
@MainActor
struct AchievementsView: View {
    @Environment(\.modelContext) private var context
    @State private var center = AchievementCenter.shared

    private let columns = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Achievement.allCases) { achievement in
                        AchievementCard(achievement: achievement,
                                        unlockedAt: center.unlockedAt(achievement),
                                        progress: center.progress(for: achievement),
                                        progressText: center.progressText(for: achievement))
                    }
                }
                Text("里程碑只在这台设备上判定，不排名、不上传。卸载重装后按你的学习记录重新算。")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .padding(Theme.Spacing.screenH)
        }
        .background(Theme.Palette.bg)
        .navigationTitle("成就")
        .navigationBarTitleDisplayMode(.inline)
        .task { center.check(context: context) }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            AnimalView(animal: .buding, size: 64, expression: .happy)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(center.unlockedCount) / \(Achievement.allCases.count)")
                    .font(Theme.Font.cardTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("已解锁的里程碑")
                    .font(Theme.Font.bodySmall)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: Theme.Radius.tile, shadowed: false)
    }
}

/// 一张成就卡：锁着的时候是灰的，解锁后变成品牌色淡底。
private struct AchievementCard: View {
    let achievement: Achievement
    let unlockedAt: Date?
    let progress: Double
    let progressText: String

    private var unlocked: Bool { unlockedAt != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: achievement.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(unlocked ? Theme.Palette.brand : Theme.Palette.textTertiary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(unlocked ? Theme.Palette.brandTint : Theme.Palette.surfaceAlt))
                Spacer()
                if unlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Palette.success)
                }
            }

            Text(achievement.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(unlocked ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)

            Text(unlocked ? achievement.detail : progressText)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            ProgressTrack(progress: progress, height: 3)
                .padding(.top, 2)

            Text(unlocked ? "已解锁" : "未解锁")
                .font(.system(size: 10))
                .foregroundStyle(unlocked ? Theme.Palette.success : Theme.Palette.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                .fill(unlocked ? Theme.Palette.brandTint : Theme.Palette.surface)
        )
    }
}

/// 解锁瞬间的全屏庆祝（1.2 秒后自动消失，也可以点掉）。
@MainActor
struct AchievementCelebrationView: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Theme.Palette.overlay.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 12) {
                AnimalView(animal: .buding, size: 104, expression: .happy, animated: true)
                Text("解锁：\(achievement.title)")
                    .font(Theme.Font.cardTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(achievement.detail)
                    .font(Theme.Font.bodySmall)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Button("知道了", action: onDismiss)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 6)
                    .frame(width: 180)
            }
            .padding(28)
            .frame(maxWidth: 300)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Palette.bg)
            )
            .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            onDismiss()
        }
    }
}