import SwiftUI
import SwiftData

/// 错词详情：看完整释义 / 例句 / 学习状态，决定「移出错词本」还是「留着继续练」。
@MainActor
struct WordDetailView: View {
    let entry: WrongWordEntry
    /// 移出 / 恢复之后通知上一页刷新。
    var onChange: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var accent: VoiceAccent = .american
    @State private var isHidden = false
    @State private var errorMessage: String?

    init(entry: WrongWordEntry, onChange: @escaping () -> Void = {}) {
        self.entry = entry
        self.onChange = onChange
    }

    private var word: Word { entry.word }
    private var state: ReviewState? { word.reviewState }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    badges.padding(.top, 14)
                    meaningCard.padding(.top, 20)
                    if !word.example.isEmpty { exampleCard.padding(.top, 14) }
                    if !word.note.isEmpty { noteCard.padding(.top, 14) }
                    statsCard.padding(.top, 14)
                    if !word.tags.isEmpty { tagsRow.padding(.top, 14) }
                    actionButtons.padding(.top, 24)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Theme.Font.bodySmall)
                            .foregroundStyle(Theme.Palette.danger)
                            .padding(.top, 12)
                    }

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, Theme.Spacing.screenH)
                .padding(.top, 8)
            }
            .background(Theme.Palette.bg)
            .navigationTitle("词条")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.Palette.brand)
                }
            }
        }
        .task {
            loadSettings()
            isHidden = state?.isWrongBookHidden ?? false
        }
    }

    // MARK: - 头

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(word.word)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 8) {
                    if !word.phonetic.isEmpty {
                        Text(word.phonetic)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    if !word.partOfSpeech.isEmpty {
                        Chip(text: word.partOfSpeech,
                             tint: Theme.Palette.textSecondary,
                             background: Theme.Palette.surfaceAlt)
                    }
                }
            }

            Spacer(minLength: 0)

            Button {
                SpeechService.shared.speak(word.word, accent: accent)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Palette.brand)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.Palette.brandTint))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("朗读 \(word.word)")
        }
    }

    private var badges: some View {
        HStack(spacing: 6) {
            Chip(text: entry.reasonText, tint: Theme.Palette.danger, background: Theme.Palette.dangerTint)
            if let last = entry.lastRating {
                Chip(text: "上次：\(last.title)",
                     tint: last.isCorrect ? Theme.Palette.success : Theme.Palette.warning,
                     background: last.isCorrect ? Theme.Palette.successTint : Theme.Palette.warningTint)
            }
            Chip(text: DueText.relative(to: entry.dueDate),
                 tint: entry.isDue ? Theme.Palette.brand : Theme.Palette.textSecondary,
                 background: entry.isDue ? Theme.Palette.brandTint : Theme.Palette.surface)
        }
    }

    // MARK: - 内容

    private var meaningCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("释义")
            Text(word.meaning)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle(radius: Theme.Radius.tile, shadowed: false)
    }

    private var exampleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("例句")
            Text(word.example)
                .font(.system(size: 15))
                .foregroundStyle(Theme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if !word.exampleTranslation.isEmpty {
                Text(word.exampleTranslation)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle(radius: Theme.Radius.tile, shadowed: false)
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("备注")
            Text(word.note)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle(radius: Theme.Radius.tile, shadowed: false)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("学习状态")
            statRow("错词次数", "\(state?.lapses ?? 0) 次")
            statRow("已复习", "\(state?.repetitions ?? 0) 次")
            statRow("当前间隔", DueText.interval(state?.intervalDays ?? 0))
            statRow("下次复习", DueText.relative(to: entry.dueDate))
            if let difficulty = state?.easeFactor {
                statRow("难度系数", String(format: "%.2f", difficulty))
            }
            if let reviewed = state?.lastReviewedAt {
                statRow("最近一次", shortDate(reviewed))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle(radius: Theme.Radius.tile, shadowed: false)
    }

    private var tagsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("标签")
            HStack(spacing: 6) {
                ForEach(word.tags, id: \.self) { tag in
                    Chip(text: tag, tint: Theme.Palette.textSecondary,
                         background: Theme.Palette.surfaceAlt)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle(radius: Theme.Radius.tile, shadowed: false)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if isHidden {
                Button {
                    restore()
                } label: {
                    Text("放回错词本")
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button {
                    hide()
                } label: {
                    Text("移出错词本")
                }
                .buttonStyle(SecondaryButtonStyle())
                Text("移出只是不再出现在列表里，复习计划不受影响；下次再判「不认识」会自动回来。")
                    .font(Theme.Font.bodySmall)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 动作

    private func hide() {
        do {
            try WrongBookService.hide(word, context: context)
            isHidden = true
            onChange()
            dismiss()
        } catch {
            errorMessage = "移出失败：\(error.localizedDescription)"
        }
    }

    private func restore() {
        do {
            try WrongBookService.restore(word, context: context)
            isHidden = false
            onChange()
            dismiss()
        } catch {
            errorMessage = "恢复失败：\(error.localizedDescription)"
        }
    }

    private func loadSettings() {
        guard let settings = try? AppSettingsStore.settings(in: context) else { return }
        accent = settings.voiceAccent
        SpeechService.shared.accent = accent
    }

    // MARK: - 小组件

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Palette.textTertiary)
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.Palette.textPrimary)
        }
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日"
        return formatter.string(from: date)
    }
}