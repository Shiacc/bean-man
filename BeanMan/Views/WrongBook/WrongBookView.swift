import SwiftUI
import SwiftData

/// 错词本 —— 根据「不认识 / 模糊」自动攒出来的词表。
///
/// 入口：今日页「错词本」那一行。
/// 数据：`WrongBookService.snapshot` 派生，不落表。
@MainActor
struct WrongBookView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = WrongBookViewModel()
    @State private var detailEntry: WrongWordEntry?
    @State private var reviewItems: [QueueItem] = []
    @State private var isReviewing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                summaryStrip
                filterBar

                if viewModel.isEmpty {
                    emptyState
                } else {
                    entryList
                }
            }
            .background(Theme.Palette.bg)
            .navigationTitle("错词本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.Palette.brand)
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "搜索单词或释义")
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
        }
        .task { viewModel.refresh(context: context) }
        .onChange(of: isReviewing) { _, reviewing in
            if !reviewing { viewModel.refresh(context: context) }
        }
        .sheet(item: $detailEntry) { entry in
            WordDetailView(entry: entry) {
                viewModel.refresh(context: context)
            }
        }
        .fullScreenCover(isPresented: $isReviewing) {
            StudyView(kind: .wrongBook, items: reviewItems)
        }
    }

    // MARK: - 顶部数字

    private var summaryStrip: some View {
        HStack(spacing: 13) {
            StatTile(title: "错词", value: "\(viewModel.visibleCount)",
                     caption: viewModel.visibleCount > 0 ? "自动收集" : "还没有")
            StatTile(title: "待复习", value: "\(viewModel.dueCount)",
                     caption: viewModel.dueCount > 0 ? "今天到期" : "都排到后面了")
            StatTile(title: "已移出", value: "\(viewModel.hiddenCount)",
                     caption: "可以恢复")
        }
        .padding(.horizontal, Theme.Spacing.screenH)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    // MARK: - 筛选

    private var filterBar: some View {
        Picker("筛选", selection: $viewModel.filter) {
            ForEach(WrongBookViewModel.Filter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Theme.Spacing.screenH)
        .padding(.bottom, 10)
    }

    // MARK: - 列表

    private var entryList: some View {
        List {
            ForEach(viewModel.entries) { entry in
                WrongWordRow(entry: entry)
                    .listRowInsets(EdgeInsets(top: 6, leading: Theme.Spacing.screenH,
                                              bottom: 6, trailing: Theme.Spacing.screenH))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Theme.Palette.bg)
                    .contentShape(Rectangle())
                    .onTapGesture { detailEntry = entry }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if entry.isHidden {
                            Button {
                                viewModel.restore(entry, context: context)
                            } label: {
                                Label("恢复", systemImage: "arrow.uturn.backward")
                            }
                            .tint(Theme.Palette.brand)
                        } else {
                            Button {
                                viewModel.hide(entry, context: context)
                            } label: {
                                Label("移出", systemImage: "eye.slash")
                            }
                            .tint(Theme.Palette.textSecondary)
                        }
                    }
            }

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(Theme.Font.bodySmall)
                    .foregroundStyle(Theme.Palette.danger)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.bg)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 0) {
                AnimalView(animal: .xueqiu, size: 132, expression: .normal)
                    .padding(.top, 36)

                Text(viewModel.emptyTitle)
                    .font(Theme.Font.cardTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .padding(.top, 20)

                Text(viewModel.emptyDetail)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 36)
                    .padding(.top, 10)

                XiaodouCard(line: "小豆小豆，错词本会自己长出来",
                            detail: "标记「不认识」时我就记一笔")
                    .padding(.horizontal, Theme.Spacing.screenH)
                    .padding(.top, 28)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 底部按钮

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let message = viewModel.errorMessage, !viewModel.isEmpty {
                Text(message)
                    .font(Theme.Font.bodySmall)
                    .foregroundStyle(Theme.Palette.danger)
            }
            Button {
                startReview()
            } label: {
                Text(viewModel.reviewButtonTitle)
            }
            .buttonStyle(PrimaryButtonStyle(enabled: viewModel.canStartReview))
            .disabled(!viewModel.canStartReview)
        }
        .padding(.horizontal, Theme.Spacing.screenH)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            Theme.Palette.bg
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.Palette.border).frame(height: 0.5)
                }
        )
    }

    private func startReview() {
        let items = viewModel.makeQueue(context: context)
        guard !items.isEmpty else { return }
        reviewItems = items
        isReviewing = true
    }
}

// MARK: - 一行

private struct WrongWordRow: View {
    let entry: WrongWordEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.word.word)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                    if !entry.word.phonetic.isEmpty {
                        Text(entry.word.phonetic)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textTertiary)
                            .lineLimit(1)
                    }
                }

                Text(entry.word.meaning)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Chip(text: entry.reasonText, tint: Theme.Palette.danger,
                         background: Theme.Palette.dangerTint)
                    if let last = entry.lastRating {
                        Chip(text: last.title,
                             tint: last.isCorrect ? Theme.Palette.success : Theme.Palette.warning,
                             background: last.isCorrect ? Theme.Palette.successTint : Theme.Palette.warningTint)
                    }
                    Chip(text: DueText.relative(to: entry.dueDate),
                         tint: entry.isDue ? Theme.Palette.brand : Theme.Palette.textSecondary,
                         background: entry.isDue ? Theme.Palette.brandTint : Theme.Palette.surface)
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Palette.textTertiary)
                .padding(.top, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                .fill(Theme.Palette.bg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                .strokeBorder(Theme.Palette.border, lineWidth: 1)
        )
        .opacity(entry.isHidden ? 0.55 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.word.word)，\(entry.word.meaning)，\(entry.reasonText)")
    }
}

// MARK: - 小标签

struct Chip: View {
    let text: String
    let tint: Color
    let background: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(background))
    }
}

#Preview("错词本") {
    WrongBookView()
        .modelContainer(BeanManStore.makePreviewContainer())
}