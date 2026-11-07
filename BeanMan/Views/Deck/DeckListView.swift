import SwiftUI
import SwiftData

/// 词库列表。Tab「词库」的第一屏。
@MainActor
struct DeckListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Deck.sortIndex) private var decks: [Deck]

    @State private var selectedDeckID: UUID?
    @State private var isImporting = false
    @State private var pendingDelete: Deck?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if decks.isEmpty {
                    emptyState
                } else {
                    deckList
                }
            }
            .background(Theme.Palette.bg)
            .navigationTitle("词库")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporting = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("导入词库")
                }
            }
            .sheet(isPresented: $isImporting) {
                ImportView { newDeckID in
                    selectedDeckID = newDeckID
                }
            }
            .alert("删除词库？", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ), presenting: pendingDelete) { deck in
                Button("删除", role: .destructive) { delete(deck) }
                Button("取消", role: .cancel) { pendingDelete = nil }
            } message: { deck in
                Text("「\(deck.name)」里的 \(deck.words.count) 个词和全部学习进度都会一起删除，不能撤销。")
            }
            .alert("出错了", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .task { refreshSelection() }
        }
    }

    // MARK: - 列表

    private var deckList: some View {
        List {
            Section {
                ForEach(decks) { deck in
                    NavigationLink {
                        DeckDetailView(deck: deck) { refreshSelection() }
                    } label: {
                        DeckRow(deck: deck, isSelected: deck.id == selectedDeckID, dueCount: dueCount(deck))
                    }
                    .listRowBackground(Theme.Palette.bg)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDelete = deck
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        Button {
                            select(deck)
                        } label: {
                            Label("设为当前", systemImage: "checkmark.circle")
                        }
                        .tint(Theme.Palette.brand)
                    }
                }
            } header: {
                Text("共 \(decks.count) 个 · \(totalWords) 个词")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            } footer: {
                Text("点词库可以查看词条；左右滑动可以设为当前或删除。")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            AnimalView(animal: .gulu, size: 132)
            XiaodouSpeech(line: "还没有词库，先导入一个？",
                          detail: "支持 CSV 文件，或者直接粘贴表格",
                          edge: .top)
            Button("导入词库") { isImporting = true }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(Theme.Spacing.screenH)
    }

    // MARK: - 数据

    private var totalWords: Int {
        decks.reduce(0) { $0 + $1.words.count }
    }

    private func dueCount(_ deck: Deck) -> Int {
        let today = DayKey.startOfDay(for: Date())
        return deck.words.reduce(0) { partial, word in
            guard let state = word.reviewState,
                  !state.isSuspended,
                  state.dueDate <= today else { return partial }
            return partial + 1
        }
    }

    private func refreshSelection() {
        if let settings = try? AppSettingsStore.current(in: context) {
            selectedDeckID = settings.selectedDeckID
        }
        if selectedDeckID == nil {
            selectedDeckID = decks.first?.id
        }
    }

    private func select(_ deck: Deck) {
        guard let settings = try? AppSettingsStore.current(in: context) else { return }
        settings.selectedDeckID = deck.id
        settings.updatedAt = Date()
        try? context.save()
        selectedDeckID = deck.id
    }

    private func delete(_ deck: Deck) {
        let wasSelected = deck.id == selectedDeckID
        context.delete(deck)
        pendingDelete = nil

        do {
            try context.save()
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
            return
        }

        if wasSelected, let first = decks.first(where: { $0.id != deck.id }) {
            select(first)
        }
        refreshSelection()
    }
}

private struct DeckRow: View {
    let deck: Deck
    let isSelected: Bool
    let dueCount: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.Palette.brandTint)
                    .frame(width: 44, height: 44)
                Image(systemName: deck.isBuiltIn ? "book.closed.fill" : "doc.text.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Palette.brand)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(deck.name)
                        .font(Theme.Font.body.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                    if deck.isBuiltIn {
                        Text("示例")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Palette.surfaceAlt, in: Capsule())
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    if isSelected {
                        Text("当前")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Palette.brandTint, in: Capsule())
                            .foregroundStyle(Theme.Palette.brandPressed)
                    }
                }
                Text(subtitle)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private var subtitle: String {
        var parts = ["\(deck.words.count) 个词"]
        if dueCount > 0 { parts.append("\(dueCount) 个待复习") }
        return parts.joined(separator: " · ")
    }
}

#Preview("词库 · 有数据") {
    DeckListView()
        .modelContainer(BeanManStore.makePreviewContainer())
}