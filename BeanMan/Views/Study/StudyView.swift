import SwiftUI
import SwiftData
import UIKit

/// 全屏学习页 —— 对应 Figma `T-02-01 学习卡·正面` / `T-02-02 学习卡·背面` / `T-02-03 学习完成`。
@MainActor
struct StudyView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = StudyViewModel()
    @State private var accent: VoiceAccent = .american
    @State private var autoPlay = true
    @State private var dragX: CGFloat = 0

    /// 引导目标位置（全局坐标）
    @State private var frames: [String: CGRect] = [:]
    private let hintCenter = HintCenter.shared

    /// 会话类型；错词本复习时带一个预设队列进来。
    private let kind: StudyKind
    private let items: [QueueItem]?

    init(kind: StudyKind = .today, items: [QueueItem]? = nil) {
        self.kind = kind
        self.items = items
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            if viewModel.finished {
                StudySummaryView(answered: viewModel.summary.answered,
                                 accuracy: viewModel.summary.accuracy,
                                 elapsed: viewModel.elapsedText,
                                 title: viewModel.kind.summaryTitle,
                                 onClose: { dismiss() })
                    .transition(.opacity)
            } else {
                cardScreen
                    .transition(.opacity)
            }
        }
        .task {
            loadSettings()
            viewModel.start(context: context, kind: kind, items: items)
            speakCurrentIfNeeded()
            // 第一张卡：先教「翻面」，再看「四档」；两条都只出现一次
            if viewModel.current != nil {
                hintCenter.request(HintCopy.request(HintID.studyFlipCard))
            }
        }
        .onPreferenceChange(FramePreferenceKey.self) { frames = $0 }
        .overlay {
            if let hint = hintCenter.current, let frame = frames[hint.id], frame.width > 1 {
                HintOverlay(target: frame, copy: HintCopy.of(hint.id)) {
                    hintCenter.dismiss()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.finished)
    }

    // MARK: - 学习卡

    private var cardScreen: some View {
        VStack(spacing: 0) {
            topBar

            GeometryReader { _ in
                ScrollView {
                    card
                        .padding(.horizontal, Theme.Spacing.screenH)
                        .padding(.top, 28)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            bottomBar
        }
        .padding(.top, 8)
    }

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .frame(width: 44, height: 44, alignment: .leading)
                }
                .accessibilityLabel("退出学习")

                Spacer()

                Text(viewModel.positionText)
                    .font(Theme.Font.date)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .monospacedDigit()
            }
            .padding(.horizontal, Theme.Spacing.screenH)

            ProgressTrack(progress: viewModel.progress, height: 3)
                .padding(.horizontal, 0)
        }
    }

    private var card: some View {
        ZStack {
            if let item = viewModel.current {
                CardFront(word: item.word,
                          isVisible: !viewModel.isFlipped,
                          onSpeak: { speak(item.word.word) },
                          onTap: { flip() })

                CardBack(word: item.word,
                         isVisible: viewModel.isFlipped,
                         onSpeak: { speak(item.word.word) },
                         onTap: { flip() })
            }
        }
        .frame(minHeight: 440)
        .offset(x: dragX)
        .rotationEffect(.degrees(Double(dragX / 28)), anchor: .bottom)
        .overlay(alignment: .top) { swipeBadge }
        .simultaneousGesture(swipeGesture)
        .onLongPressGesture(minimumDuration: 0.45) {
            longPressAction()
        }
        .animation(.easeInOut(duration: 0.42), value: viewModel.isFlipped)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: dragX)
        .captureFrame(HintID.studyFlipCard)
    }

    /// 拖动时浮在最上面的「不认识 / 认识」，松手就消失。
    private var swipeBadge: some View {
        Group {
            if dragX < -24 {
                badge("不认识", color: Theme.Palette.danger, tint: Theme.Palette.dangerTint)
            } else if dragX > 24 {
                badge("认识", color: Theme.Palette.success, tint: Theme.Palette.successTint)
            }
        }
        .offset(y: -14)
        .opacity(swipeBadgeOpacity)
        .allowsHitTesting(false)
    }

    /// 拖动距离映射成 0...1 的透明度。写死类型，避免 CGFloat / Int 混算的歧义。
    private var swipeBadgeOpacity: Double {
        let distance: CGFloat = abs(dragX)
        let ratio: CGFloat = distance / 90.0
        return Double(min(max(ratio, 0), 1))
    }

    private func badge(_ text: String, color: Color, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(tint, in: Capsule())
    }

    /// 左滑 = 不认识，右滑 = 认识（没翻面时右滑只翻面，避免瞎评「认识」）。
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                dragX = value.translation.width
            }
            .onEnded { value in
                let threshold: CGFloat = 72
                let dx = value.translation.width
                dragX = 0

                if dx < -threshold {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    rate(.again)
                } else if dx > threshold {
                    if viewModel.isFlipped {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        rate(.good)
                    } else {
                        flip()
                    }
                }
            }
    }

    /// 长按：朗读 + 收藏（不动记忆曲线）。
    private func longPressAction() {
        guard let word = viewModel.current?.word else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        speak(word.word)
        word.isFavorite.toggle()
        try? context.save()
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if viewModel.isFlipped {
                Text("这个词记得怎么样？")
                    .font(Theme.Font.bodySmall)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                RatingBar { rating in
                    rate(rating)
                }
            } else {
                Text("轻点翻面 · 左滑不认识 · 长按朗读")
                    .font(Theme.Font.bodySmall)
                    .foregroundStyle(Theme.Palette.textTertiary)
                Button {
                    flip()
                } label: {
                    Text("显示答案")
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            if viewModel.canUndo {
                Button {
                    viewModel.undo(context: context)
                    speakCurrentIfNeeded()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 11, weight: .medium))
                        Text("撤销上一张")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Theme.Palette.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.screenH)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .captureFrame(HintID.studyRateButtons)
    }

    // MARK: - 动作

    private func flip() {
        viewModel.flip()
        // 翻面之后立刻教四档评分（只教一次）
        if viewModel.isFlipped {
            hintCenter.request(HintCopy.request(HintID.studyRateButtons, priority: 5))
        }
    }

    private func rate(_ rating: Rating) {
        viewModel.rate(rating, context: context)
        speakCurrentIfNeeded()
    }

    private func loadSettings() {
        guard let settings = try? AppSettingsStore.settings(in: context) else { return }
        accent = settings.voiceAccent
        autoPlay = settings.autoPlay
        SpeechService.shared.accent = accent
    }

    private func speak(_ text: String) {
        SpeechService.shared.speak(text, accent: accent)
    }

    private func speakCurrentIfNeeded() {
        guard autoPlay, let word = viewModel.current?.word.word else { return }
        speak(word)
    }
}

// MARK: - 正面

private struct CardFront: View {
    let word: Word
    let isVisible: Bool
    let onSpeak: () -> Void
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Text(word.word)
                .font(Theme.Font.wordLarge)
                .foregroundStyle(Theme.Palette.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if !word.phonetic.isEmpty {
                Text(word.phonetic)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.top, 8)
            }

            Button(action: onSpeak) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.Palette.brand)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Theme.Palette.brandTint))
            }
            .buttonStyle(.plain)
            .padding(.top, 32)
            .accessibilityLabel("朗读 \(word.word)")

            Spacer(minLength: 0)

            Text("点击卡片查看释义")
                .font(Theme.Font.bodySmall)
                .foregroundStyle(Theme.Palette.textTertiary)
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, minHeight: 440)
        .cardStyle(radius: Theme.Radius.studyCard)
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.studyCard, style: .continuous))
        .onTapGesture(perform: onTap)
        .opacity(isVisible ? 1 : 0)
        .rotation3DEffect(.degrees(isVisible ? 0 : -90), axis: (x: 0, y: 1, z: 0))
        .accessibilityHidden(!isVisible)
    }
}

// MARK: - 背面

private struct CardBack: View {
    let word: Word
    let isVisible: Bool
    let onSpeak: () -> Void
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(word.word)
                        .font(Theme.Font.wordMedium)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    if !word.phonetic.isEmpty {
                        Text(word.phonetic)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                Spacer()
                Button(action: onSpeak) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.Palette.brand)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("朗读 \(word.word)")
            }

            if !word.partOfSpeech.isEmpty {
                Text(word.partOfSpeech)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.Palette.surfaceAlt))
                    .padding(.top, 16)
            }

            Text(word.meaning)
                .font(Theme.Font.meaning)
                .foregroundStyle(Theme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Rectangle()
                .fill(Theme.Palette.border)
                .frame(height: 0.5)
                .padding(.top, 22)

            if !word.example.isEmpty {
                sectionLabel("例句")
                Text(word.example)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(word.exampleTranslation)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }

            if !word.note.isEmpty {
                sectionLabel("备注").padding(.top, 20)
                Text(word.note)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, minHeight: 440, alignment: .topLeading)
        .cardStyle(radius: Theme.Radius.studyCard)
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.studyCard, style: .continuous))
        .onTapGesture(perform: onTap)
        .opacity(isVisible ? 1 : 0)
        .rotation3DEffect(.degrees(isVisible ? 0 : 90), axis: (x: 0, y: 1, z: 0))
        .accessibilityHidden(!isVisible)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Palette.textTertiary)
            .padding(.top, 18)
            .padding(.bottom, 6)
    }
}