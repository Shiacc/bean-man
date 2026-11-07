import SwiftUI
import SwiftData
import UIKit

/// 首次启动引导（PRD F1）：4 步 —— 每日计划 / 提醒 / 发音 / 词库。
///
/// 设计原则：
/// - 只写 `AppSettings`，不碰词库与学习记录；
/// - 每一步都能「跳过」：跳过提醒不阻断后续，用户随时可以在设置里改；
/// - 通知权限只在这一步请求一次，拒绝后不纠缠（设置页有入口）。
@MainActor
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<AppSettings> { $0.key == "app" })
    private var settingsRows: [AppSettings]

    /// 完成或跳过后的回调
    var onFinish: () -> Void

    @State private var step = 0
    @State private var dailyNew = 20
    @State private var dailyReview = 100
    @State private var reminderEnabled = true
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
    @State private var accent: VoiceAccent = .american
    @State private var reminderDenied = false
    @State private var hasLoaded = false
    /// 「自定义」被显式选中时才展开滑杆，避免和 10/20/30 同时出现
    @State private var usesCustomNew = false

    private let newOptions = [10, 20, 30]

    var body: some View {
        VStack(spacing: 0) {
            progressDots
                .padding(.top, 28)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch step {
                    case 0: planStep
                    case 1: reminderStep
                    case 2: accentStep
                    default: deckStep
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenH)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }

            bottomBar
        }
        .background(Theme.Palette.bg)
        .task {
            guard !hasLoaded, let settings = settingsRows.first else { return }
            hasLoaded = true
            dailyNew = settings.dailyNewLimit
            dailyReview = settings.dailyReviewLimit
            usesCustomNew = !newOptions.contains(settings.dailyNewLimit)
            reminderEnabled = settings.reminderEnabled
            accent = settings.voiceAccent
            reminderTime = Calendar.current.date(from: DateComponents(hour: settings.reminderHour,
                                                                     minute: settings.reminderMinute)) ?? reminderTime
        }
        .alert("通知没打开", isPresented: $reminderDenied) {
            Button("去系统设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("先不提醒", role: .cancel) {}
        } message: {
            Text("没有通知权限就收不到每日提醒。你可以先跳过，之后在设置里再开。")
        }
    }

    // MARK: - 步骤指示

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index == step ? Theme.Palette.brand : Theme.Palette.surfaceAlt)
                    .frame(width: index == step ? 22 : 8, height: 8)
                    .animation(.easeOut(duration: 0.2), value: step)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel("第 \(step + 1) 步，共 4 步")
    }

    // MARK: - 第 1 步：每日计划

    private var planStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            CompanionBubble(animal: .juzi,
                            line: "每天想背多少个新词？",
                            detail: "先定个能坚持的数，之后随时能改")
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 12) {
                Text("每天新词")
                    .font(Theme.Font.bodySmall.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)

                HStack(spacing: 10) {
                    ForEach(newOptions, id: \.self) { option in
                        Button {
                            dailyNew = option
                            usesCustomNew = false
                        } label: {
                            Text("\(option)")
                                .font(Theme.Font.cardTitle)
                                .foregroundStyle(dailyNew == option && !usesCustomNew ? Color.white : Theme.Palette.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(dailyNew == option && !usesCustomNew ? Theme.Palette.brand : Theme.Palette.surface,
                                            in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("每天 \(option) 个新词")
                    }

                    Button {
                        usesCustomNew = true
                    } label: {
                        Text("自定义")
                            .font(Theme.Font.button)
                            .foregroundStyle(usesCustomNew ? Color.white : Theme.Palette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 22)
                            .background(usesCustomNew ? Theme.Palette.brand : Theme.Palette.surface,
                                        in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("自定义每天新词数")
                }

                if usesCustomNew {
                    Stepper(value: $dailyNew, in: 5...60, step: 5) {
                        HStack {
                            Text("每天新词")
                            Spacer()
                            Text("\(dailyNew) 个")
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .monospacedDigit()
                        }
                        .font(Theme.Font.body)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.Palette.surface,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Stepper(value: $dailyReview, in: 20...300, step: 20) {
                    HStack {
                        Text("每天复习上限")
                        Spacer()
                        Text("\(dailyReview) 个")
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .monospacedDigit()
                    }
                    .font(Theme.Font.body)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.Palette.surface,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                Text("到期词一般不会超。上限只是防止某天堆几百个复习。")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
    }

    // MARK: - 第 2 步：提醒

    private var reminderStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            CompanionBubble(animal: .manman,
                            line: "要不要每天提醒你一下？",
                            detail: "固定时间发一条本地通知，不联网")

            VStack(spacing: 0) {
                Toggle("每日提醒", isOn: $reminderEnabled)
                    .font(Theme.Font.body)
                    .padding(16)

                if reminderEnabled {
                    Divider().overlay(Theme.Palette.border)
                    DatePicker("提醒时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .font(Theme.Font.body)
                        .padding(16)
                }
            }
            .background(Theme.Palette.surface,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

            Text("提醒只在你这台设备上触发。系统关了通知权限就收不到，可以在设置里重新打开。")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
        }
    }

    // MARK: - 第 3 步：发音

    private var accentStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            CompanionBubble(animal: .jiujiu,
                            line: "想听美音还是英音？",
                            detail: "用的是系统语音，不下载音频包")

            HStack(spacing: 12) {
                ForEach([VoiceAccent.american, .british], id: \.self) { option in
                    Button {
                        accent = option
                        SpeechService.shared.accent = option
                        SpeechService.shared.speak("journey")
                    } label: {
                        VStack(spacing: 6) {
                            Text(option == .american ? "美音" : "英音")
                                .font(Theme.Font.cardTitle)
                            Text(option == .american ? "en-US" : "en-GB")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.textTertiary)
                        }
                        .foregroundStyle(accent == option ? Color.white : Theme.Palette.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(accent == option ? Theme.Palette.brand : Theme.Palette.surface,
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                SpeechService.shared.accent = accent
                SpeechService.shared.speak("abandon")
            } label: {
                Label("试听一下", systemImage: "speaker.wave.2.fill")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    // MARK: - 第 4 步：词库

    private var deckStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            CompanionBubble(animal: .gulu,
                            line: "词库已经准备好了",
                            detail: "24 个示例词，先背起来；想换随时导入自己的")

            VStack(alignment: .leading, spacing: 10) {
                Label("内置示例词库 24 词", systemImage: "book.closed")
                Label("支持导入 CSV（单词 / 音标 / 词性 / 释义 …）", systemImage: "square.and.arrow.down")
                Label("支持导出 JSON 备份", systemImage: "square.and.arrow.up")
                Label("所有数据只存在这台设备上", systemImage: "lock.shield")
            }
            .font(Theme.Font.body)
            .foregroundStyle(Theme.Palette.textSecondary)
            .labelStyle(OnboardingLabelStyle())
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

            Text("导入入口在「词库」页右上角。")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
        }
    }

    // MARK: - 底部按钮

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Button {
                advance()
            } label: {
                Text(step == 3 ? "开始使用" : "下一步")
            }
            .buttonStyle(PrimaryButtonStyle())

            Button(step == 0 ? "跳过引导" : "上一步") {
                if step == 0 {
                    finish()
                } else {
                    step -= 1
                }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.horizontal, Theme.Spacing.screenH)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    // MARK: - 动作

    private func advance() {
        if step < 3 {
            if step == 1 && reminderEnabled {
                Task { await requestReminderPermissionIfNeeded() }
            }
            step += 1
        } else {
            finish()
        }
    }

    private func requestReminderPermissionIfNeeded() async {
        let granted = await NotificationService.shared.requestAuthorization()
        if !granted {
            reminderDenied = true
            reminderEnabled = false
        }
    }

    private func finish() {
        guard let settings = settingsRows.first else {
            onFinish()
            return
        }

        settings.dailyNewLimit = dailyNew
        settings.dailyReviewLimit = dailyReview
        settings.reminderEnabled = reminderEnabled
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        settings.reminderHour = components.hour ?? 20
        settings.reminderMinute = components.minute ?? 0
        settings.voiceAccent = accent
        settings.onboardingCompleted = true
        settings.updatedAt = Date()

        SpeechService.shared.accent = accent
        try? context.save()

        if reminderEnabled {
            Task {
                let granted = await NotificationService.shared.requestAuthorization()
                if granted {
                    await NotificationService.shared.scheduleDaily(hour: settings.reminderHour,
                                                                   minute: settings.reminderMinute)
                }
            }
        }
        onFinish()
    }
}

/// 引导页里的清单图标对齐样式。
private struct OnboardingLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            configuration.icon
                .foregroundStyle(Theme.Palette.brand)
                .frame(width: 22)
            configuration.title
        }
    }
}

#Preview("引导") {
    OnboardingView {}
        .modelContainer(BeanManStore.makePreviewContainer())
}