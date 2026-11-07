import SwiftUI
import SwiftData

/// 单词本·卡片浏览（对应 Figma `T-03-01`）。
///
/// 手势约定与学习卡刻意错开，避免肌肉记忆串台：
/// - 轻点 → 下一个
/// - 左滑 → 移出错词本（不是「不认识」，这里不做评分）
/// - 右滑 → 收藏 / 取消收藏
@MainActor
struct WrongBookCardsView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = WrongBookViewModel()
    @State private var index = 0
    @State private var dragX: CGFloat = 0
    @State private var showsEmpty = false

    private var entries: [WrongWordEntry] { viewModel.entries }

    private var current: WrongWordEntry? {
        entries.indices.contains(index) ? entries[index] : nil
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            if let entry = current {
                VStack(spacing: 0) {
                    topBar

                    Spacer(minLength: 0)

                    card(entry)
                        .padding(.horizontal, Theme.Spacing.screenH)

                    Spacer(minLength: 0)

                    hints
                        .padding(.bottom, 18)
                }
            } else {
                emptyState
            }
        }
        .task { viewModel.refresh(context: context) }
        .onChange(of: viewModel.entries.count) { _, newValue in
            if index >= newValue { index = max(0, newValue - 1) }
        }
    }

    // MARK: - 卡片

    private func card(_ entry: WrongWordEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(entry.reasonText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Palette.warning)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.Palette.warningTint, in: Capsule())
                Spacer()
                if entry.word.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Palette.brand)
                }
            }

            Spacer(minLength: 0)

            Text(entry.word.word)
                .font(Theme.Font.wordLarge)
                .foregroundStyle(Theme.Palette.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(2)

            if !entry.word.phonetic.isEmpty {
                Text(entry.word.phonetic)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.top, 8)
            }

            Text(entry.word.partOfSpeech.isEmpty
                 ? entry.word.meaning
                 : "\(entry.word.partOfSpeech) \(entry.word.meaning)")
                .font(Theme.Font.meaning)
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.top, 18)
                .fixedSize(horizontal: false, vertical: true)

            if !entry.word.example.isEmpty {
                Text(entry.word.example)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.top, 14)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Text("\(index + 1) / \(entries.count)")
                .font(Theme.Font.date)
                .foregroundStyle(Theme.Palette.textTertiary)
                .monospacedDigit()
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, minHeight: 380, alignment: .leading)
        .cardStyle(radius: Theme.Radius.studyCard)
        .offset(x: dragX)
        .rotationEffect(.degrees(Double(dragX / 32)), anchor: .bottom)
        .overlay(alignment: .top) { swipeBadge }
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.studyCard, style: .continuous))
        .onTapGesture { advance() }
        .gesture(dragGesture(entry))
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: dragX)
    }

    private var swipeBadge: some View {
        Group {
            if dragX < -24 {
                pill("移出错词本", color: Theme.Palette.danger, tint: Theme.Palette.dangerTint)
            } else if dragX > 24 {
                pill("收藏", color: Theme.Palette.brand, tint: Theme.Palette.brandTint)
            }
        }
        .offset(y: -14)
        .opacity(swipeBadgeOpacity)
        .allowsHitTesting(false)
    }

    /// 同 StudyView：写死 CGFloat / Double，别让编译器在 `/` 上做类型推断。
    private var swipeBadgeOpacity: Double {
        let distance: CGFloat = abs(dragX)
        let ratio: CGFloat = distance / 90.0
        return Double(min(max(ratio, 0), 1))
    }

    private func pill(_ text: String, color: Color, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(tint, in: Capsule())
    }

    private func dragGesture(_ entry: WrongWordEntry) -> some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in dragX = value.translation.width }
            .onEnded { value in
                let dx = value.translation.width
                dragX = 0
                if dx < -72 {
                    viewModel.hide(entry, context: context)
                } else if dx > 72 {
                    entry.word.isFavorite.toggle()
                    try? context.save()
                    advance()
                }
            }
    }

    private func advance() {
        if index + 1 < entries.count {
            index += 1
        } else {
            index = 0
        }
    }

    // MARK: - 顶栏 / 提示

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .frame(width: 44, height: 44, alignment: .leading)
            }
            .accessibilityLabel("关闭")

            Spacer()

            Text("单词本 · 卡片")
                .font(Theme.Font.date)
                .foregroundStyle(Theme.Palette.textTertiary)

            Spacer()

            Text("\(entries.count)")
                .font(Theme.Font.date)
                .foregroundStyle(Theme.Palette.textTertiary)
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, Theme.Spacing.screenH)
    }

    private var hints: some View {
        HStack(spacing: 18) {
            hint(icon: "hand.tap", text: "轻点下一个")
            hint(icon: "arrow.left", text: "左滑移出")
            hint(icon: "arrow.right", text: "右滑收藏")
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.Palette.textTertiary)
    }

    private func hint(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(text)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            AnimalView(animal: .xueqiu, size: 128, expression: .normal)
            Text("错词本是空的")
                .font(Theme.Font.cardTitle)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("学习时选「不认识」或「模糊」，词就会出现在这里。")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("回今日") { dismiss() }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 4)
        }
    }
}

#Preview("单词本卡片") {
    WrongBookCardsView()
        .modelContainer(BeanManStore.makePreviewContainer())
}