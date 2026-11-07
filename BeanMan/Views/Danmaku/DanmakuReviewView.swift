import SwiftUI
import SwiftData

/// 弹幕复习：像片尾演职人员表一样匀速滚动，每个词占 1–2 行。
///
/// 设计约定（见 PRD §5.13）：
/// - 全程只有两种交互：轻点暂停/继续、右滑退出（另有右上角「结束」）
/// - 不显示任何学习状态（不认识/错了几次），只给词本身
/// - 深浅两套主题，切换不重置位置
/// - 退出记住位置，下次从原处继续
@MainActor
struct DanmakuReviewView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = DanmakuReviewViewModel()
    @State private var dragOffset: CGFloat = 0
    @State private var showsExitHint = false

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height

            ZStack(alignment: .top) {
                viewModel.theme.background
                    .ignoresSafeArea()

                if let message = viewModel.errorMessage {
                    emptyState(message)
                } else {
                    scrollingContent(size: geo.size, isLandscape: isLandscape)
                }

                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                if viewModel.isPaused {
                    pausedOverlay
                }

                if showsExitHint {
                    hintPill
                        .transition(.opacity)
                }
            }
            .offset(x: dragOffset)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.18)) {
                    viewModel.togglePause()
                }
            }
            .gesture(exitGesture)
        }
        .task {
            viewModel.load(context: context)
            if viewModel.shouldShowExitHint {
                showsExitHint = true
                viewModel.markExitHintShown()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation(.easeInOut(duration: 0.3)) { showsExitHint = false }
            }
        }
        .onDisappear { viewModel.savePosition() }
        .statusBarHidden()
    }

    // MARK: - 滚动主体

    private func scrollingContent(size: CGSize, isLandscape: Bool) -> some View {
        TimelineView(.animation) { timeline in
            let offset = viewModel.offset(at: timeline.date)

            VStack(spacing: 0) {
                ForEach(viewModel.lines) { line in
                    lineView(line, isLandscape: isLandscape)
                }
                // 第二份用于无缝循环：第一份滚出去时它正好接上
                ForEach(viewModel.lines) { line in
                    lineView(line, isLandscape: isLandscape)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(y: -offset)
            .frame(width: size.width, height: size.height, alignment: .top)
            .clipped()
            .overlay(alignment: .bottom) {
                progressBar(at: timeline.date)
            }
        }
    }

    /// 竖屏两行（单词 + 音标 / 词性 + 释义），横屏压成一行。
    private func lineView(_ line: DanmakuReviewViewModel.Line, isLandscape: Bool) -> some View {
        Group {
            if isLandscape {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(line.word)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(viewModel.theme.primary)
                    if !line.phonetic.isEmpty {
                        Text(line.phonetic)
                            .font(.system(size: 12))
                            .foregroundStyle(viewModel.theme.tertiary)
                    }
                    Text(detailText(line))
                        .font(.system(size: 13))
                        .foregroundStyle(viewModel.theme.secondary)
                        .lineLimit(1)
                }
            } else {
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(line.word)
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(viewModel.theme.primary)
                        if !line.phonetic.isEmpty {
                            Text(line.phonetic)
                                .font(.system(size: 12))
                                .foregroundStyle(viewModel.theme.tertiary)
                        }
                    }
                    Text(detailText(line))
                        .font(.system(size: 13))
                        .foregroundStyle(viewModel.theme.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: DanmakuReviewViewModel.blockHeight)
        .padding(.horizontal, 20)
    }

    private func detailText(_ line: DanmakuReviewViewModel.Line) -> String {
        line.partOfSpeech.isEmpty ? line.meaning : "\(line.partOfSpeech) \(line.meaning)"
    }

    private func progressBar(at date: Date) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(viewModel.theme.tertiary.opacity(0.2))
                Capsule()
                    .fill(Theme.Palette.brand)
                    .frame(width: max(0, geo.size.width * viewModel.progress(at: date)))
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    // MARK: - 顶栏

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { viewModel.toggleTheme() }
            } label: {
                chip(text: viewModel.theme == .dark ? "◐ 深色" : "◑ 浅色")
            }

            Menu {
                ForEach(DanmakuReviewViewModel.speedOptions, id: \.self) { option in
                    Button {
                        viewModel.setSpeed(option)
                    } label: {
                        Text(option == floor(option) ? "\(Int(option))×" : "\(option)×")
                    }
                }
            } label: {
                chip(text: viewModel.speedText)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(viewModel.theme.secondary)
                    .frame(width: 34, height: 34)
                    .background(viewModel.theme.tertiary.opacity(0.14), in: Circle())
            }
            .accessibilityLabel("结束复习")
        }
    }

    private func chip(text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(viewModel.theme.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(viewModel.theme.tertiary.opacity(0.14), in: Capsule())
    }

    // MARK: - 暂停 / 提示 / 空态

    private var pausedOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "pause.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(viewModel.theme.primary)
            Text("已暂停")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(viewModel.theme.primary)
            Text("轻点任意处继续")
                .font(.system(size: 12))
                .foregroundStyle(viewModel.theme.tertiary)

            Button("结束复习") { dismiss() }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(viewModel.theme.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(viewModel.theme.tertiary.opacity(0.16), in: Capsule())
                .padding(.top, 4)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    private var hintPill: some View {
        VStack {
            Spacer()
            Text("← 右滑退出")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(viewModel.theme.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(viewModel.theme.tertiary.opacity(0.16), in: Capsule())
                .padding(.bottom, 40)
        }
        .allowsHitTesting(false)
    }

    private func emptyState(_ message: String) -> some View {
        VStack(spacing: 14) {
            AnimalView(animal: .paopao, size: 120, expression: .sleepy)
            Text(message)
                .font(Theme.Font.body)
                .foregroundStyle(viewModel.theme.secondary)
            Button("回今日") { dismiss() }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Palette.brand)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 右滑退出

    private var exitGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard value.translation.width > 0 else { return }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                if value.translation.width > 80 {
                    viewModel.savePosition()
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

#Preview("弹幕复习") {
    DanmakuReviewView()
        .modelContainer(BeanManStore.makePreviewContainer())
}