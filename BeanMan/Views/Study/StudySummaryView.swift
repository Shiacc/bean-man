import SwiftUI
import UIKit
import SwiftData

/// 学习完成页 —— 对应 Figma `T-02-03 学习完成`。
struct StudySummaryView: View {
    @Environment(\.modelContext) private var context

    let answered: Int
    let accuracy: Int
    let elapsed: String
    /// 完成页标题。今日任务是「今天的词过完了」，错词本是另一句。
    var title: String = "今天的词过完了"
    let onClose: () -> Void

    @State private var streak = 0
    @State private var perWordText = "—"
    @State private var celebrating = false

    init(answered: Int,
         accuracy: Int,
         elapsed: String,
         title: String = "今天的词过完了",
         onClose: @escaping () -> Void) {
        self.answered = answered
        self.accuracy = accuracy
        self.elapsed = elapsed
        self.title = title
        self.onClose = onClose
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 完成页的「庆祝」：布丁（柯基）是「完成庆祝」这一格的角色。
                // 出场：从 0.86 弹到 1，同时撒一圈纸屑；Reduce Motion 时直接定格。
                ZStack {
                    ConfettiBurst(isActive: celebrating)
                    SceneArtView(scene: .onboardingDone, height: 200)
                        .padding(.horizontal, 48)
                        .scaleEffect(celebrating ? 1 : 0.86)
                        .opacity(celebrating ? 1 : 0)
                        .offset(y: celebrating ? 0 : 10)
                }
                .frame(height: 208)
                .padding(.top, 36)
                .onAppear {
                    guard !UIAccessibility.isReduceMotionEnabled else {
                        celebrating = true
                        return
                    }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                        celebrating = true
                    }
                }

                Text(title)
                    .font(Theme.Font.cardTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .padding(.top, 24)

                Text("\(answered) 张卡，全部完成")
                    .font(Theme.Font.date)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.top, 8)

                HStack(spacing: 13) {
                    StatTile(title: "正确率", value: "\(accuracy)%", caption: "本次会话")
                    StatTile(title: "用时", value: elapsed, caption: perWordCaption)
                    StatTile(title: "连续打卡", value: streak > 0 ? "\(streak) 天" : "—",
                             caption: streak > 0 ? "保持住" : "今天开个头")
                }
                .padding(.top, 32)

                XiaodouCard(line: Xiaodou.line(.sessionDone(accuracy: accuracy, streak: streak)),
                            detail: Xiaodou.detail(.sessionDone(accuracy: accuracy, streak: streak)))
                    .padding(.top, 22)

                Button {
                    onClose()
                } label: {
                    Text("回到今日")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 28)

                Button {
                    onClose()
                } label: {
                    Text("再复习错词")
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 12)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, Theme.Spacing.screenH)
        }
        .background(Theme.Palette.bg)
        .task { refreshStats() }
    }

    private var perWordCaption: String {
        guard answered > 0 else { return "—" }
        return "平均 \(perWordText)/词"
    }

    private func refreshStats() {
        do {
            streak = DayKey.streak(from: try StudyRepository.studiedDayKeys(context: context))
        } catch {
            streak = 0
        }
        // 用时文本形如 "6:12"，换算成每词秒数
        let parts = elapsed.split(separator: ":").compactMap { Int($0) }
        if parts.count == 2, answered > 0 {
            let seconds = parts[0] * 60 + parts[1]
            perWordText = "\(max(1, seconds / max(1, answered))) 秒"
        }
    }
}

/// 完成页的一小把纸屑：12 个点从中心弹出去。
/// 只做位移和透明度，不引入粒子系统；Reduce Motion 由调用方直接定格。
private struct ConfettiBurst: View {
    let isActive: Bool

    private var colors: [Color] {
        [Theme.Palette.brand, Theme.Palette.success, Theme.Palette.warning,
         Theme.Palette.brandSoft, Theme.Palette.dangerTint, Theme.Palette.surfaceAlt]
    }

    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                let angle = Double(index) / 12.0 * 2.0 * .pi
                Circle()
                    .fill(colors[index % colors.count])
                    .frame(width: index.isMultiple(of: 3) ? 10 : 7,
                           height: index.isMultiple(of: 3) ? 10 : 7)
                    .offset(x: cos(angle) * (isActive ? 96 : 12),
                            y: sin(angle) * (isActive ? 82 : 12))
                    .opacity(isActive ? 0.85 : 0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}