import SwiftUI
import SwiftData

/// 学习完成页 —— 对应 Figma `T-02-03 学习完成`。
struct StudySummaryView: View {
    @Environment(\.modelContext) private var context

    let answered: Int
    let accuracy: Int
    let elapsed: String
    let onClose: () -> Void

    @State private var streak = 0
    @State private var perWordText = "—"

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.Palette.brand)
                    .frame(width: 96, height: 96)
                    .background(Circle().fill(Theme.Palette.brandTint))
                    .padding(.top, 60)

                Text("今天的词过完了")
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