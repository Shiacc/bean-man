import SwiftUI
import SwiftData
import Charts

/// 设置 → 小豆分析：把小豆「怎么想」摊开给用户看（PRD §5.14.4）。
///
/// 三个部分：四个时段的正确率、常错 Top3、当前所有洞察（含冷却状态）。
/// 数据全部本地现算，不落表、不上传。
@MainActor
struct InsightPanelView: View {
    @Environment(\.modelContext) private var context
    @State private var snapshot = InsightSnapshot.empty
    @State private var center = InsightCenter.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sectionGap) {
                hourCard
                wrongWordsCard
                insightsCard
                rulesCard
            }
            .padding(.horizontal, Theme.Spacing.screenH)
            .padding(.vertical, 12)
        }
        .background(Theme.Palette.bg)
        .navigationTitle("小豆分析")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
    }

    // MARK: - 时段

    private var totalAnswered: Int {
        snapshot.hourBuckets.reduce(0) { $0 + $1.answered }
    }

    private var hourCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("一天里什么时候最准")
                    .font(Theme.Font.cardTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Text("样本 \(totalAnswered)")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .monospacedDigit()
            }

            if totalAnswered == 0 {
                Text("还没有学习记录。学满 10 次、某个时段够 5 次，小豆才会下结论。")
                    .font(Theme.Font.bodySmall)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Chart {
                    ForEach(snapshot.hourBuckets) { bucket in
                        BarMark(x: .value("时段", bucket.label),
                                y: .value("正确率", bucket.accuracyPercent))
                        .foregroundStyle(bucket.answered >= 5 ? Theme.Palette.brand : Theme.Palette.surfaceAlt)
                        .cornerRadius(4)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxisLabel("正确率 %")
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                .frame(height: 150)

                VStack(spacing: 6) {
                    ForEach(snapshot.hourBuckets) { bucket in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(bucket.answered >= 5 ? Theme.Palette.brand : Theme.Palette.surfaceAlt)
                                .frame(width: 6, height: 6)
                            Text(bucket.label)
                                .font(Theme.Font.bodySmall)
                                .foregroundStyle(Theme.Palette.textSecondary)
                            Text("样本 \(bucket.answered)")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.textTertiary)
                                .monospacedDigit()
                            Spacer(minLength: 0)
                            Text(bucket.answered == 0 ? "—" : "\(bucket.accuracyPercent)%")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.Palette.textPrimary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(shadowed: false)
    }

    // MARK: - 常错词

    private var wrongWordsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最该再见的几个词")
                .font(Theme.Font.cardTitle)
                .foregroundStyle(Theme.Palette.textPrimary)

            if snapshot.recommendations.isEmpty {
                Text("暂时没有「错得多又不到期」的词。")
                    .font(Theme.Font.bodySmall)
                    .foregroundStyle(Theme.Palette.textSecondary)
            } else {
                ForEach(snapshot.recommendations) { item in
                    HStack(spacing: 10) {
                        Text(item.word)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text(item.reason)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        Spacer(minLength: 0)
                    }
                }
                Text("这些词会额外加进今天的学习队列，不占每日新词额度。")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(shadowed: false)
    }

    // MARK: - 全部洞察

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("小豆现在想说的")
                .font(Theme.Font.cardTitle)
                .foregroundStyle(Theme.Palette.textPrimary)

            if snapshot.insights.isEmpty {
                Text("数据还不够，小豆先不开口。")
                    .font(Theme.Font.bodySmall)
                    .foregroundStyle(Theme.Palette.textSecondary)
            } else {
                ForEach(snapshot.insights) { insight in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text(insight.detail)
                            .font(Theme.Font.bodySmall)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if center.isDismissed(insight.kind) {
                            Text("已收起 · 7 天后再提")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.textTertiary)
                        } else {
                            Button("知道了") {
                                center.dismiss(insight.kind)
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Palette.brand)
                        }
                    }
                    .padding(.vertical, 2)

                    if insight.id != snapshot.insights.last?.id {
                        Rectangle()
                            .fill(Theme.Palette.border)
                            .frame(height: 0.5)
                    }
                }
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(shadowed: false)
    }

    // MARK: - 规则

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("规则")
                .font(Theme.Font.cardTitle)
                .foregroundStyle(Theme.Palette.textPrimary)

            ForEach(Self.rules, id: \.self) { rule in
                HStack(alignment: .top, spacing: 8) {
                    Text("·")
                        .font(Theme.Font.bodySmall)
                        .foregroundStyle(Theme.Palette.textTertiary)
                    Text(rule)
                        .font(Theme.Font.bodySmall)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(shadowed: false)
    }

    private static let rules = [
        "一天切四段：早上 5–11 点、下午 11–17 点、晚上 17–23 点、深夜 23–5 点。",
        "总共学满 10 次才做时段分析，单个时段够 5 次才参与比较。",
        "推荐词只挑「错过、又不在今天到期队列里」的词，最多 3 个。",
        "点「知道了」之后 7 天内不再主动提，设置页仍能看到。",
        "全部统计都在本机完成，不进云、不进备份。"
    ]

    private func load() {
        snapshot = (try? InsightEngine.snapshot(context: context)) ?? .empty
    }
}

#Preview("小豆分析") {
    NavigationStack {
        InsightPanelView()
    }
    .modelContainer(BeanManStore.makePreviewContainer())
}