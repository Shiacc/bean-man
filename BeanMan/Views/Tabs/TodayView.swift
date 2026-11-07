import SwiftUI
import SwiftData

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
                                detail: Xiaodou.detail(viewModel.xiaodouMoment))
                    .padding(.horizontal, Theme.Spacing.screenH)
                taskCard
                    .padding(.horizontal, Theme.Spacing.screenH)
                statTiles
                    .padding(.horizontal, Theme.Spacing.screenH)
                    .captureFrame(HintID.todayStatTiles)
                actions
                    .padding(.horizontal, Theme.Spacing.screenH)
            }
            .padding(.top, 12)
            // 底部自绘 TabBar 是浮在内容上的，留出它 + home indicator 的高度
            .padding(.bottom, 108)
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

            Button {
                if viewModel.hasAnyDueOrNew {
                    isStudying = true
                } else {
                    isShowingWrongBook = true
                }
            } label: {
                Text(viewModel.hasAnyDueOrNew ? "开始学习" : "复习错词")
            }
            .buttonStyle(PrimaryButtonStyle(enabled: true))
            .disabled(viewModel.deckName.isEmpty)
            .padding(.top, 18)
            .captureFrame(HintID.todayStartStudy)
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
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
        }
    }
}

#Preview("今日 · 有任务") {
    TodayView()
        .modelContainer(BeanManStore.makePreviewContainer())
}