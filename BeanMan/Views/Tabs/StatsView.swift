import SwiftUI
import SwiftData
import Charts

/// 统计页：连续打卡、今日、7 天柱状图、掌握度。
@MainActor
struct StatsView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = StatsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.sectionGap) {
                    streakCard
                    statGrid
                    weekCard
                    masteryCard
                }
                .padding(.horizontal, Theme.Spacing.screenH)
                .padding(.vertical, 12)
            }
            .background(Theme.Palette.bg)
            .navigationTitle("统计")
            .task { viewModel.refresh(context: context) }
            .refreshable { viewModel.refresh(context: context) }
        }
    }

    // MARK: - 卡片

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(viewModel.streakText)
                    .font(Theme.Font.bigNumber)
                    .foregroundStyle(Theme.Palette.brand)
                    .monospacedDigit()
                Text("天连续打卡")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.Palette.brand)
            }

            Text("本周一共过了 \(viewModel.weekTotalText) 个词")
                .font(Theme.Font.bodySmall)
                .foregroundStyle(Theme.Palette.textSecondary)

            Text(Xiaodou.line(viewModel.xiaodouMoment))
                .font(Theme.Font.bodySmall)
                .foregroundStyle(Theme.Palette.brandPressed)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.cardPadding)
        .background(Theme.Palette.brandTint, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var statGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatTile(title: "今日已学", value: "\(viewModel.snapshot.learnedToday)", caption: "个")
                StatTile(title: "待复习", value: "\(viewModel.snapshot.dueToday)", caption: "个")
            }
            HStack(spacing: 12) {
                StatTile(title: "学过", value: "\(viewModel.snapshot.learnedWords)", caption: "共 \(viewModel.snapshot.totalWords) 个")
                StatTile(title: "正确率", value: viewModel.snapshot.reviewedTotal == 0 ? "—" : viewModel.snapshot.accuracyText, caption: "累计")
            }
        }
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("最近 7 天")
                    .font(Theme.Font.cardTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                HStack(spacing: 10) {
                    legend(color: Theme.Palette.brand, text: "新词")
                    legend(color: Theme.Palette.brandSoft, text: "复习")
                }
            }

            if viewModel.hasAnyHistory {
                Chart {
                    ForEach(viewModel.snapshot.last7Days) { day in
                        BarMark(x: .value("日期", day.weekdayLabel),
                                y: .value("新词", day.newWords))
                        .foregroundStyle(by: .value("类型", "新词"))
                        .cornerRadius(4)

                        BarMark(x: .value("日期", day.weekdayLabel),
                                y: .value("复习", day.reviews))
                        .foregroundStyle(by: .value("类型", "复习"))
                        .cornerRadius(4)
                    }
                }
                .chartForegroundStyleScale([
                    "新词": Theme.Palette.brand,
                    "复习": Theme.Palette.brandSoft
                ])
                .chartLegend(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Theme.Palette.border)
                        AxisValueLabel()
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                .frame(height: 168)
            } else {
                emptyWeek
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .cardStyle(shadowed: false)
    }

    private var emptyWeek: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.system(size: 26))
                .foregroundStyle(Theme.Palette.textTertiary)
            Text("还没有学习记录，学完一轮就会出现在这里")
                .font(Theme.Font.bodySmall)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 168)
    }

    private var masteryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("掌握度")
                    .font(Theme.Font.cardTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Text(viewModel.masteryText)
                    .font(Theme.Font.statNumber)
                    .foregroundStyle(Theme.Palette.success)
                    .monospacedDigit()
            }

            ProgressTrack(progress: viewModel.snapshot.masteredProgress, height: 10)

            Text("\(viewModel.snapshot.masteredWords) 个词已经记牢（连续复习 3 次以上、间隔超过 3 周）")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(Theme.Spacing.cardPadding)
        .cardStyle(shadowed: false)
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
    }
}

#Preview("统计") {
    StatsView()
        .modelContainer(BeanManStore.makePreviewContainer())
}