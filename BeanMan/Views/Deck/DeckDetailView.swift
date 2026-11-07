import SwiftUI
import SwiftData

/// 单个词库的词表：搜索、查看、删除、设为当前。
@MainActor
struct DeckDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let deck: Deck
    var onChange: () -> Void = {}

    @State private var searchText = ""
    @State private var selectedWord: Word?
    @State private var pendingDelete: Word?
    @State private var isSelectedDeck = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                summaryCard
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                if words.isEmpty {
                    Text(searchText.isEmpty ? "这个词库还没有词" : "没有找到「\(searchText)」")
                        .font(Theme.Font.bodySmall)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                } else {
                    ForEach(words) { word in
                        Button {
                            selectedWord = word
                        } label: {
                            WordRow(word: word)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.Palette.bg)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDelete = word
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                Text("共 \(deck.words.count) 个词")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.bg)
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜单词或释义")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    selectDeck()
                } label: {
                    Label(isSelectedDeck ? "当前词库" : "设为当前",
                          systemImage: isSelectedDeck ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .disabled(isSelectedDeck)
            }
        }
        .sheet(item: $selectedWord) { word in
            WordSheet(word: word)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("删除这个词？", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        ), presenting: pendingDelete) { word in
            Button("删除", role: .destructive) { delete(word) }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: { word in
            Text("「\(word.word)」会被删除，相关的复习记录也会一起清理。")
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

    // MARK: - 组件

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(deck.summary.isEmpty ? "没有简介" : deck.summary)
                .font(Theme.Font.bodySmall)
                .foregroundStyle(Theme.Palette.textSecondary)

            HStack(spacing: 8) {
                StatTile(title: "词条", value: "\(deck.words.count)", caption: "个")
                StatTile(title: "待复习", value: "\(dueCount)", caption: "个")
                StatTile(title: "已掌握", value: "\(masteredCount)", caption: "个")
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .cardStyle(shadowed: false)
        .padding(.horizontal, Theme.Spacing.screenH)
        .padding(.vertical, 8)
    }

    // MARK: - 数据

    private var words: [Word] {
        let all = deck.words.sorted { $0.sortIndex < $1.sortIndex }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return all }
        return all.filter { word in
            word.word.lowercased().contains(query)
                || word.meaning.lowercased().contains(query)
                || word.phonetic.lowercased().contains(query)
        }
    }

    private var dueCount: Int {
        let today = DayKey.startOfDay(for: Date())
        return deck.words.filter { word in
            guard let state = word.reviewState else { return false }
            return !state.isSuspended && state.dueDate <= today
        }.count
    }

    private var masteredCount: Int {
        deck.words.filter { word in
            guard let state = word.reviewState else { return false }
            return state.repetitions >= 3 && state.intervalDays >= 21
        }.count
    }

    private func refreshSelection() {
        if let settings = try? AppSettingsStore.current(in: context) {
            isSelectedDeck = settings.selectedDeckID == deck.id
        }
    }

    private func selectDeck() {
        guard let settings = try? AppSettingsStore.current(in: context) else { return }
        settings.selectedDeckID = deck.id
        settings.updatedAt = Date()
        do {
            try context.save()
            isSelectedDeck = true
            onChange()
        } catch {
            errorMessage = "设置失败：\(error.localizedDescription)"
        }
    }

    private func delete(_ word: Word) {
        deck.words.removeAll { $0.id == word.id }
        context.delete(word)
        pendingDelete = nil
        do {
            try context.save()
            onChange()
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
    }
}

private struct WordRow: View {
    let word: Word

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(word.word)
                    .font(Theme.Font.body.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                if !word.phonetic.isEmpty {
                    Text(word.phonetic)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                if word.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.Palette.warning)
                }
                Spacer(minLength: 0)
            }
            Text(word.meaning)
                .font(Theme.Font.bodySmall)
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// 词条详情（轻量版，只读）。
private struct WordSheet: View {
    let word: Word

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(word.word)
                            .font(Theme.Font.wordLarge)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Button {
                            SpeechService.shared.speak(word.word)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.Palette.brand)
                        }
                        .buttonStyle(.plain)
                    }
                    HStack(spacing: 8) {
                        if !word.phonetic.isEmpty {
                            Text(word.phonetic)
                                .font(Theme.Font.bodySmall)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                        if !word.partOfSpeech.isEmpty {
                            Text(word.partOfSpeech)
                                .font(Theme.Font.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.Palette.brandTint, in: Capsule())
                                .foregroundStyle(Theme.Palette.brandPressed)
                        }
                    }
                }

                Text(word.meaning)
                    .font(Theme.Font.meaning)
                    .foregroundStyle(Theme.Palette.textPrimary)

                if !word.example.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(word.example)
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        if !word.exampleTranslation.isEmpty {
                            Text(word.exampleTranslation)
                                .font(Theme.Font.bodySmall)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                }

                if !word.note.isEmpty {
                    Text(word.note)
                        .font(Theme.Font.bodySmall)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.screenH)
        }
        .background(Theme.Palette.bg)
    }
}

// 预览依赖具体词库对象，交给 DeckListView 的预览进入即可。