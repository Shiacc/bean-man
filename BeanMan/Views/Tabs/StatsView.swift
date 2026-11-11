import SwiftUI
import SwiftData
import Charts

/// 统计页：连续打卡、今日、7 天柱状图、未来 7 天到期曲线、掌握度。
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
                    forecastCard
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

    // MARK: - 未来 7 天到期

    private var forecastCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("未来 7 天到期")
                    .font(Theme.Font.cardTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Text(viewModel.forecastTotalText)
                    .font(Theme.Font.statNumber)
                    .foregroundStyle(Theme.Palette.brand)
                    .monospacedDigit()
                Text("个")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }

            if viewModel.hasForecast {
                forecastChart
            } else {
                emptyForecast
            }

            Text(viewModel.forecastNote)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.cardPadding)
        .cardStyle(shadowed: false)
    }

    private var forecastChart: some View {
        Chart {
            ForEach(viewModel.snapshot.forecast.days) { day in
                AreaMark(x: .value("日期", day.label),
                         y: .value("到期", day.due))
                .foregroundStyle(
                    LinearGradient(colors: [Theme.Palette.brand.opacity(0.26),
                                            Theme.Palette.brand.opacity(0.02)],
                                   startPoint: .top,
                                   endPoint: .bottom)
                )

                LineMark(x: .value("日期", day.label),
                         y: .value("到期", day.due))
                .foregroundStyle(Theme.Palette.brand)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                PointMark(x: .value("日期", day.label),
                          y: .value("到期", day.due))
                .foregroundStyle(day.isToday ? Theme.Palette.brandPressed : Theme.Palette.brand)
                .symbolSize(day.isToday ? 64 : 24)
            }
        }
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
        .frame(height: 150)
    }

    private var emptyForecast: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 26))
                .foregroundStyle(Theme.Palette.textTertiary)
            Text("未来一周没有到期词，先学新词")
                .font(Theme.Font.bodySmall)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
    }

    private var masteryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("掌握度")
                    .font(Theme.Font.cardTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Text("\(viewModel.snapshot.masteredWords) / \(viewModel.snapshot.totalWords) 个")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .monospacedDigit()
            }

            if viewModel.hasMasteryData {
                HStack(spacing: 20) {
                    masteryRing
                    masteryLegend
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("还没有词，先去「词库」导入或加词")
                    .font(Theme.Font.bodySmall)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("连续复习 3 次以上、间隔超过 3 周才算掌握")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
        }
        .padding(Theme.Spacing.cardPadding)
        .cardStyle(shadowed: false)
    }

    /// 三段环：未学 / 学习中 / 已掌握（PRD §5.8）。
    private var masteryRing: some View {
        ZStack {
            Chart {
                ForEach(viewModel.visibleMasterySegments) { segment in
                    SectorMark(angle: .value("词", segment.value),
                               innerRadius: .ratio(0.66),
                               angularInset: 1.5)
                    .cornerRadius(3)
                    .foregroundStyle(masteryColor(segment.kind))
                }
            }
            .chartLegend(.hidden)
            .frame(width: 126, height: 126)

            VStack(spacing: 2) {
                Text(viewModel.masteryText)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.Palette.success)
                    .monospacedDigit()
                Text("已掌握")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
    }

    private var masteryLegend: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(viewModel.masterySegments) { segment in
                HStack(spacing: 8) {
                    Circle()
                        .fill(masteryColor(segment.kind))
                        .frame(width: 8, height: 8)
                    Text(segment.label)
                        .font(Theme.Font.bodySmall)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Spacer(minLength: 0)
                    Text("\(segment.value)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func masteryColor(_ kind: MasterySegment.Kind) -> Color {
        switch kind {
        case .untouched: return Theme.Palette.surfaceAlt
        case .learning: return Theme.Palette.brand
        case .mastered: return Theme.Palette.success
        }
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