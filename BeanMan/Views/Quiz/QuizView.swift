import SwiftUI
import SwiftData

/// 测试页：三种题型轮流出现，答完给成绩。
@MainActor
struct QuizView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = QuizViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.finished {
                    summary
                } else if viewModel.questions.isEmpty {
                    emptyState
                } else {
                    questionPage
                }
            }
            .background(Theme.Palette.bg)
            .navigationTitle("测试")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                if viewModel.questions.isEmpty && !viewModel.finished {
                    viewModel.start(context: context)
                }
            }
        }
    }

    // MARK: - 答题

    private var questionPage: some View {
        VStack(spacing: 0) {
            ProgressTrack(progress: viewModel.progress)
                .padding(.horizontal, Theme.Spacing.screenH)
                .padding(.top, 8)

            HStack {
                Text(viewModel.positionText)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .monospacedDigit()
                Spacer()
                if let kind = viewModel.current?.kind {
                    Text(kind.title)
                        .font(Theme.Font.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.Palette.brandTint, in: Capsule())
                        .foregroundStyle(Theme.Palette.brandPressed)
                }
            }
            .padding(.horizontal, Theme.Spacing.screenH)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 18) {
                    promptCard
                    if let question = viewModel.current {
                        answerArea(question)
                    }
                }
                .padding(Theme.Spacing.screenH)
            }

            bottomBar
        }
    }

    private var promptCard: some View {
        VStack(spacing: 12) {
            if let question = viewModel.current {
                if question.kind == .spelling {
                    Text("根据释义拼出单词")
                        .font(Theme.Font.bodySmall)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text(question.prompt)
                        .font(Theme.Font.meaning)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .multilineTextAlignment(.center)
                } else {
                    Button {
                        if let text = question.spokenText {
                            SpeechService.shared.speak(text)
                        }
                    } label: {
                        VStack(spacing: 10) {
                            if question.kind == .listening {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Theme.Palette.brand)
                                Text("点一下再听一遍")
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Palette.textTertiary)
                            } else {
                                Text(question.prompt)
                                    .font(Theme.Font.wordLarge)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .cardStyle()
        .onChange(of: viewModel.index) { _, _ in
            speakIfNeeded()
        }
        .task { speakIfNeeded() }
    }

    @ViewBuilder
    private func answerArea(_ question: QuizQuestion) -> some View {
        if question.kind == .spelling {
            VStack(spacing: 12) {
                TextField("输入单词", text: $viewModel.typedAnswer)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(Theme.Font.meaning)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 14)
                    .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                    .disabled(viewModel.isAnswered)
                    .submitLabel(.done)
                    .onSubmit { viewModel.submitTyped(context: context) }

                if viewModel.isAnswered {
                    feedback(question)
                }
            }
        } else {
            VStack(spacing: 10) {
                ForEach(question.options, id: \.self) { option in
                    optionRow(option, question: question)
                }
                if viewModel.isAnswered {
                    feedback(question)
                }
            }
        }
    }

    private func optionRow(_ option: String, question: QuizQuestion) -> some View {
        let isSelected = viewModel.selectedOption == option
        let isAnswer = option == question.answer
        let showCorrect = viewModel.isAnswered && isAnswer
        let showWrong = viewModel.isAnswered && isSelected && !isAnswer

        return Button {
            viewModel.choose(option)
        } label: {
            HStack(spacing: 10) {
                Text(option)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if showCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Palette.success)
                } else if showWrong {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Palette.danger)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background(for: showCorrect, showWrong),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                    .stroke(Theme.Palette.border, lineWidth: showCorrect || showWrong ? 0 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isAnswered)
    }

    private func background(for correct: Bool, _ wrong: Bool) -> Color {
        if correct { return Theme.Palette.successTint }
        if wrong { return Theme.Palette.dangerTint }
        return Theme.Palette.bg
    }

    private func feedback(_ question: QuizQuestion) -> some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.lastWasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(viewModel.lastWasCorrect ? Theme.Palette.success : Theme.Palette.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.lastWasCorrect ? "答对了" : "正确答案：\(question.answer)")
                    .font(Theme.Font.bodySmall.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(question.meaning)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((viewModel.lastWasCorrect ? Theme.Palette.successTint : Theme.Palette.dangerTint),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(Theme.Palette.border)
            Button {
                if viewModel.isAnswered {
                    viewModel.next(context: context)
                } else {
                    viewModel.submitTyped(context: context)
                }
            } label: {
                Text(viewModel.isAnswered ? (viewModel.index + 1 == viewModel.total ? "看成绩" : "下一题") : "提交")
            }
            .buttonStyle(PrimaryButtonStyle(enabled: viewModel.isAnswered || viewModel.canSubmit))
            .disabled(!viewModel.isAnswered && !viewModel.canSubmit)
            .padding(Theme.Spacing.screenH)
        }
        .background(Theme.Palette.bg)
    }

    // MARK: - 空 / 完成

    private var emptyState: some View {
        VStack(spacing: 18) {
            AnimalView(animal: .paopao, size: 132)
            XiaodouSpeech(line: "先学几个词，测试才有题",
                          detail: "学过的词不少于 4 个就能出题",
                          edge: .top)
            Button("回去学习") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(Theme.Spacing.screenH)
    }

    private var summary: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Theme.Palette.surfaceAlt, lineWidth: 12)
                    .frame(width: 132, height: 132)
                Circle()
                    .trim(from: 0, to: viewModel.accuracy)
                    .stroke(Theme.Palette.brand,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 132, height: 132)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(viewModel.accuracyText)
                        .font(Theme.Font.bigNumber)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("正确率")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }

            Text("答对 \(viewModel.correctCount) / \(viewModel.total)")
                .font(Theme.Font.cardTitle)
                .foregroundStyle(Theme.Palette.textPrimary)

            Text(viewModel.resultText)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button("再测一次") {
                    viewModel.restart(context: context)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("返回今日") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.Spacing.screenH)
        }
        .background(Theme.Palette.bg)
    }

    // MARK: - 发音

    private func speakIfNeeded() {
        guard let question = viewModel.current else { return }
        if question.kind == .listening, let text = question.spokenText {
            SpeechService.shared.speak(text)
        }
    }
}

#Preview("测试") {
    QuizView()
        .modelContainer(BeanManStore.makePreviewContainer())
}