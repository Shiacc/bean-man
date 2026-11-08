import SwiftUI
import SwiftData

/// 生词本：学习卡上长按收藏的词会进这里。
///
/// 不建表——`Word.isFavorite` 本身就是状态，收藏夹只是它的一个查询。
/// 这样删词库、删词、备份恢复都不需要额外同步。
@MainActor
struct FavoritesView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Word.createdAt, order: .reverse) private var allWords: [Word]

    @State private var searchText = ""
    @State private var detailWord: Word?

    private var favorites: [Word] {
        let base = allWords.filter(\.isFavorite)
        guard !searchText.isEmpty else { return base }
        let key = searchText.lowercased()
        return base.filter {
            $0.normalized.contains(key) || $0.meaning.lowercased().contains(key)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allWords.filter(\.isFavorite).isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(Theme.Palette.bg)
            .navigationTitle("生词本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.Palette.brand)
                }
            }
            .searchable(text: $searchText, prompt: "搜单词或释义")
            .sheet(item: $detailWord) { word in
                FavoriteDetailSheet(word: word) {
                    detailWord = nil
                }
            }
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(favorites) { word in
                    Button {
                        detailWord = word
                    } label: {
                        row(word)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            unfavorite(word)
                        } label: {
                            Label("移出", systemImage: "star.slash")
                        }
                    }
                }
            } footer: {
                Text("学习卡上长按单词可以收藏；星标只存在本机。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func row(_ word: Word) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(word.word)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    if !word.phonetic.isEmpty {
                        Text(word.phonetic)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                }
                Text(word.meaning)
                    .font(Theme.Font.bodySmall)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.Palette.warning)
        }
        .padding(.vertical, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            AnimalView(animal: .zhima, size: 132, expression: .normal, animated: true)
            XiaodouCard(line: "还没有收藏的词", detail: "学习卡上长按单词就能收进来")
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.screenH)
    }

    private func unfavorite(_ word: Word) {
        word.isFavorite = false
        try? context.save()
    }
}

/// 收藏夹里的详情：比错词本详情轻，只展示词本身。
private struct FavoriteDetailSheet: View {

    let word: Word
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(word.word)
                                .font(Theme.Font.wordLarge)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            if !word.phonetic.isEmpty {
                                Text(word.phonetic)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.Palette.textTertiary)
                            }
                        }
                        if !word.partOfSpeech.isEmpty {
                            Text(word.partOfSpeech)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }

                    Text(word.meaning)
                        .font(Theme.Font.meaning)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !word.example.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("例句")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.textTertiary)
                            Text(word.example)
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            if !word.exampleTranslation.isEmpty {
                                Text(word.exampleTranslation)
                                    .font(Theme.Font.bodySmall)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                    }

                    if !word.note.isEmpty {
                        Text(word.note)
                            .font(Theme.Font.bodySmall)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                .padding(Theme.Spacing.screenH)
            }
            .background(Theme.Palette.bg)
            .navigationTitle("收藏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                        onClose()
                    }
                    .foregroundStyle(Theme.Palette.brand)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        word.isFavorite = false
                        try? context.save()
                        dismiss()
                        onClose()
                    } label: {
                        Image(systemName: "star.slash")
                    }
                    .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
    }
}