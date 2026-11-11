import SwiftUI
import SwiftData
import UIKit

/// 今日页 —— 对应 Figma `T-01-01 今日·有任务` / `T-01-02 今日·已完成`。
///
/// 标记 `@MainActor`：`@State private var viewModel = TodayViewModel()` 的默认值
/// 在属性初始化器里求值，而 ViewModel 是 `@MainActor` 隔离的；不加这行在严格并发下会报
/// 「Call to main actor-isolated initializer in a synchronous nonisolated context」。
@MainActor
struct TodayView: View {
    @Environment(\.modelContext) private var context
    /// 由 `RootView` 注入；直接预览时为 nil，所以写成可选
    @Environment(AppRouter.self) private var router: AppRouter?

    @State private var viewModel = TodayViewModel()
    @State private var isStudying = false
    @State private var isShowingWrongBook = false
    @State private var isShowingQuiz = false
    @State private var isShowingAchievements = false
    @State private var isShowingFavorites = false
    @State private var isShowingShare = false
    @State private var isReviewingDanmaku = false

    /// 引导目标的位置（全局坐标），由 `.captureFrame` 上报
    @State private var frames: [String: CGRect] = [:]
    private let hintCenter = HintCenter.shared

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日 · EEE"
        return formatter.string(from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sectionGap) {
                header
                CompanionBubble(animal: .juzi,
                                line: Xiaodou.line(viewModel.xiaodouMoment),
                                detail: Xiaodou.detail(viewModel.xiaodouMoment),
                                expression: viewModel.xiaodouExpression)
                    .padding(.horizontal, Theme.Spacing.screenH)
                taskCard
                    .padding(.horizontal, Theme.Spacing.screenH)
                if !viewModel.visibleInsights.isEmpty || viewModel.hasRecommendations {
                    insightCard
                        .padding(.horizontal, Theme.Spacing.screenH)
                }
                statTiles
                    .padding(.horizontal, Theme.Spacing.screenH)
                    .captureFrame(HintID.todayStatTiles)
                    // 长按统计块 → 生成打卡分享图（PRD §5.16 / AC-80）
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 0.5) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isShowingShare = true
                    }
                    .accessibilityAction(named: "分享打卡图") {
                        isShowingShare = true
                    }
                actions
                    .padding(.horizontal, Theme.Spacing.screenH)
            }
            .padding(.top, 12)
            // 底部 TabBar 在 VStack 里、不浮在内容上，这里只需常规留白
            .padding(.bottom, 24)
        }
        .background(Theme.Palette.bg)
        .task {
            viewModel.refresh(context: context)
            // 第一次进今日页，指一下「开始学习」；看过就不再打扰
            hintCenter.request(HintCopy.request(HintID.todayStartStudy))
        }
        .onPreferenceChange(FramePreferenceKey.self) { frames = $0 }
        .overlay {
            if let hint = hintCenter.current, let frame = frames[hint.id], frame.width > 1 {
                HintOverlay(target: frame, copy: HintCopy.of(hint.id)) {
                    hintCenter.dismiss()
                }
            }
        }
        .onChange(of: isStudying) { _, studying in
            if !studying { viewModel.refresh(context: context) }
        }
        .onChange(of: isShowingWrongBook) { _, showing in
            if !showing { viewModel.refresh(context: context) }
        }
        .onChange(of: isShowingQuiz) { _, showing in
            if !showing { viewModel.refresh(context: context) }
        }
        .fullScreenCover(isPresented: $isStudying) {
            StudyView()
        }
        .sheet(isPresented: $isShowingWrongBook) {
            WrongBookView()
        }
        .sheet(isPresented: $isShowingQuiz) {
            QuizView()
        }
        .sheet(isPresented: $isShowingAchievements) {
            NavigationStack { AchievementsView() }
        }
        .sheet(isPresented: $isShowingFavorites) {
            FavoritesView()
        }
        .fullScreenCover(isPresented: $isReviewingDanmaku) {
            DanmakuReviewView()
        }
        .sheet(isPresented: $isShowingShare) {
            ShareCardSheet(content: shareContent)
        }
    }

    // MARK: - 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("今日")
                .font(Theme.Font.screenTitle)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(dateText)
                .font(Theme.Font.date)
                .foregroundStyle(Theme.Palette.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.screenH)
        .padding(.top, 24)
    }

    // MARK: - 今日任务卡

    private var taskCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("今日任务")
                .font(Theme.Font.bodySmall)
                .foregroundStyle(Theme.Palette.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(viewModel.counts.due)")
                        .font(Theme.Font.bigNumber)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("个待复习")
                        .font(Theme.Font.bodySmall)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(viewModel.counts.new)")
                        .font(Theme.Font.bigNumber)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("个新词")
                        .font(Theme.Font.bodySmall)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .padding(.top, 6)

            ProgressTrack(progress: viewModel.todayProgress)
                .padding(.top, 20)
            Text("今日进度 \(viewModel.counts.learnedToday) / \(viewModel.counts.learnedToday + viewModel.counts.total)")
                .font(.system(size: 11))
                .foregroundStyle(Theme.Palette.textTertiary)
                .padding(.top, 8)

            if viewModel.counts.new > 0, let note = viewModel.dailyNewLimitNote {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Palette.warning)
                    .padding(.top, 6)
            }

            Button {
                if viewModel.deckName.isEmpty {
                    // 没有词库时这个按钮不是「开始学习」，直接把人送到词库页（AC-10）
                    router?.tab = .decks
                } else if viewModel.hasAnyDueOrNew {
                    isStudying = true
                } else {
                    isShowingWrongBook = true
                }
            } label: {
                Text(viewModel.deckName.isEmpty ? "去词库选一个"
                     : (viewModel.hasAnyDueOrNew ? "开始学习" : "复习错词"))
            }
            .buttonStyle(PrimaryButtonStyle(enabled: true))
            .padding(.top, 18)
            .captureFrame(HintID.todayStartStudy)
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - 小豆的分析

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                Text("小豆的分析")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Theme.Palette.brand)

            if let insight = viewModel.headlineInsight {
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(insight.detail)
                        .font(Theme.Font.bodySmall)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 每条洞察都得能「去做」或「知道了」（PRD §5.14.4）
                HStack(spacing: 12) {
                    if let actionTitle = insight.actionTitle {
                        Button(actionTitle) {
                            perform(insight)
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Palette.onBrand)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Theme.Palette.brand, in: Capsule())
                    }

                    Button("知道了") {
                        viewModel.dismiss(insight)
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.textTertiary)
                }
            }

            if !viewModel.insight.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("这 \(viewModel.insight.recommendations.count) 个词今天会一起出现")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)

                    ForEach(viewModel.insight.recommendations) { item in
                        HStack(spacing: 8) {
                            Text(item.word)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text(item.reason)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.Palette.textSecondary)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.brandTint, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
    }

    /// 洞察的「去做」：按类型把人送到该去的地方（PRD §5.14.4）。
    /// 时段洞察落到设置页，因为它的动作就是「改提醒时间」。
    private func perform(_ insight: Insight) {
        switch insight.kind {
        case .bestHour:
            router?.tab = .settings
        case .backlog, .streakRisk, .firstWeek:
            isStudying = true
        case .wrongWords:
            isShowingWrongBook = true
        }
    }

    // MARK: - 三连统计

    private var statTiles: some View {
        HStack(spacing: 13) {
            StatTile(title: "今日已学",
                     value: viewModel.learnedText,
                     caption: viewModel.remainText)
            StatTile(title: "正确率",
                     value: viewModel.accuracyText,
                     caption: viewModel.answered > 0 ? "今天为止" : "还没有评分")
            StatTile(title: "连续打卡",
                     value: viewModel.streakText,
                     caption: viewModel.streak > 0 ? "保持住" : "今天开个头")
        }
    }

    // MARK: - 分享

    /// 分享卡的内容：与统计块同源，避免「统计显示 18、分享图写 17」。
    private var shareContent: ShareCardContent {
        ShareCardContent.make(streak: viewModel.streak,
                              learnedToday: viewModel.counts.learnedToday,
                              learnedWords: viewModel.learnedWordCount,
                              dueToday: viewModel.counts.due)
    }

    // MARK: - 快捷入口

    private var actions: some View {
        VStack(spacing: 12) {
            ActionRow(icon: "text.badge.xmark",
                      title: "错词本",
                      subtitle: viewModel.wrongCount > 0 ? "\(viewModel.wrongCount) 个" : "暂无") {
                isShowingWrongBook = true
            }
            ActionRow(icon: "checkmark.circle",
                      title: "测试一下",
                      subtitle: viewModel.learnedWordCount >= 4 ? "选择题 · 拼写 · 听音" : "学过 4 个词后可用") {
                isShowingQuiz = true
            }
            ActionRow(icon: "book.closed",
                      title: viewModel.deckName,
                      subtitle: "\(viewModel.totalWordCount) 词") {
                router?.tab = .decks
            }
            ActionRow(icon: "text.line.last.and.arrowtriangle.forward",
                      title: "弹幕复习",
                      subtitle: "滚动过一遍，点一下就暂停") {
                isReviewingDanmaku = true
            }
            ActionRow(icon: "star",
                      title: "生词本",
                      subtitle: viewModel.favoriteCount > 0 ? "\(viewModel.favoriteCount) 个" : "暂无") {
                isShowingFavorites = true
            }
            ActionRow(icon: "square.and.arrow.up",
                      title: "分享打卡图",
                      subtitle: viewModel.learnedWordCount > 0 ? "生成 1080 × 1350 图片" : "先学几个词再来") {
                isShowingShare = true
            }
            ActionRow(icon: "rosette",
                      title: "成就与里程碑",
                      subtitle: "已解锁 \(AchievementCenter.shared.unlockedCount) / \(Achievement.allCases.count)") {
                isShowingAchievements = true
            }
        }
    }
}

#Preview("今日 · 有任务") {
    TodayView()
        .modelContainer(BeanManStore.makePreviewContainer())
}