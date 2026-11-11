import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

/// 设置页：计划、提醒、发音、数据、关于。
@MainActor
struct SettingsView: View {
    @Query(filter: #Predicate<AppSettings> { $0.key == "app" })
    private var settingsRows: [AppSettings]

    var body: some View {
        NavigationStack {
            Group {
                if let settings = settingsRows.first {
                    SettingsForm(settings: settings)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("设置")
        }
    }
}

@MainActor
private struct SettingsForm: View {
    @Bindable var settings: AppSettings

    @Query private var decks: [Deck]

    @Environment(\.modelContext) private var context

    @State private var isExporting = false
    @State private var exportDocument: BackupDocument?
    @State private var isImporting = false
    @State private var pendingRestore: BackupFile?
    @State private var isConfirmingReset = false
    @State private var notice: String?
    @State private var errorMessage: String?
    @State private var reminderDenied = false
    @State private var isShowingPaywall = false
    @State private var purchase = PurchaseService.shared

    var body: some View {
        Form {
            Section {
                Stepper(value: $settings.dailyNewLimit, in: 5...60, step: 5) {
                    labeled("每日新词", value: "\(settings.dailyNewLimit) 个")
                }
                Stepper(value: $settings.dailyReviewLimit, in: 20...300, step: 20) {
                    labeled("每日复习上限", value: "\(settings.dailyReviewLimit) 个")
                }
            } header: {
                Text("学习计划")
            } footer: {
                Text("新词和复习各自有额度，改完从下一次进入今日页开始生效。")
                    .font(Theme.Font.caption)
            }

            Section {
                Toggle("每日提醒", isOn: $settings.reminderEnabled)
                    .onChange(of: settings.reminderEnabled) { _, enabled in
                        applyReminder(enabled: enabled)
                    }

                if settings.reminderEnabled {
                    DatePicker("提醒时间",
                               selection: reminderTime,
                               displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("提醒")
            } footer: {
                Text("提醒是本地通知，不联网。在系统设置里关掉通知后，这里也会失效。")
                    .font(Theme.Font.caption)
            }

            Section {
                Picker("发音口音", selection: Binding(
                    get: { settings.voiceAccent },
                    set: { settings.voiceAccent = $0 }
                )) {
                    Text("美音").tag(VoiceAccent.american)
                    Text("英音").tag(VoiceAccent.british)
                }
                .onChange(of: settings.voiceAccent) { _, accent in
                    SpeechService.shared.accent = accent
                }

                Toggle("自动朗读", isOn: $settings.autoPlay)

                Button("试听") {
                    SpeechService.shared.accent = settings.voiceAccent
                    SpeechService.shared.speak("abandon")
                }
            } header: {
                Text("发音")
            }

            Section {
                if purchase.isPro {
                    LabeledContent("豆卡单词 Pro", value: "已解锁（买断）")
                } else {
                    Button {
                        isShowingPaywall = true
                    } label: {
                        Label("解锁全部功能", systemImage: "sparkles")
                    }
                    LabeledContent("免费额度", value: "1 个词库 · 500 词 · 每日 20 新词")
                }

                NavigationLink {
                    AchievementsView()
                } label: {
                    Label("成就与里程碑", systemImage: "rosette")
                }
            } header: {
                Text("升级")
            } footer: {
                Text(purchase.isPro
                     ? "一次性买断，恢复购买可在更换设备后用同一个 Apple ID 找回。"
                     : "免费版功能完整，只在词库数量、词条总数和每日新词上有限制。")
                    .font(Theme.Font.caption)
            }

            Section {
                NavigationLink {
                    InsightPanelView()
                } label: {
                    Label("小豆分析", systemImage: "sparkles")
                }
            } header: {
                Text("小豆")
            } footer: {
                Text("看小豆是怎么得出结论的：时段正确率、常错词和规则。全部在本机计算。")
                    .font(Theme.Font.caption)
            }

            Section {
                Button {
                    prepareExport()
                } label: {
                    Label("导出备份（JSON）", systemImage: "square.and.arrow.up")
                }

                Button {
                    isImporting = true
                } label: {
                    Label("从备份恢复", systemImage: "square.and.arrow.down")
                }

                Button(role: .destructive) {
                    isConfirmingReset = true
                } label: {
                    Label("重置学习进度", systemImage: "arrow.counterclockwise")
                }

                Button {
                    restoreBuiltInLibrary()
                } label: {
                    Label(hasBuiltInLibrary ? "内置词库已在" : "恢复内置词库",
                          systemImage: "books.vertical")
                }
                .disabled(hasBuiltInLibrary)
            } header: {
                Text("数据")
            } footer: {
                Text("备份包含词库、词条和每个词的记忆状态；恢复时遇到同名词库会跳过，不会覆盖现在的进度。")
                    .font(Theme.Font.caption)
            }

            Section {
                LabeledContent("版本", value: BackupService.appVersion)
                NavigationLink {
                    DesignGalleryView()
                } label: {
                    Label("设计验收", systemImage: "paintpalette")
                }
            } header: {
                Text("关于")
            } footer: {
                Text("豆卡单词不收集任何个人信息：没有账号、没有网络请求，所有数据只存在这台设备上。")
                    .font(Theme.Font.caption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.bg)
        .onAppear {
            SpeechService.shared.accent = settings.voiceAccent
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(reason: .manual) { isShowingPaywall = false }
        }
        .fileExporter(isPresented: $isExporting,
                      document: exportDocument,
                      contentType: .json,
                      defaultFilename: BackupService.suggestedFileName()) { result in
            if case let .failure(error) = result {
                errorMessage = "导出失败：\(error.localizedDescription)"
            }
        }
        .fileImporter(isPresented: $isImporting,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false) { result in
            handleImport(result)
        }
        .alert("恢复备份？", isPresented: Binding(
            get: { pendingRestore != nil },
            set: { if !$0 { pendingRestore = nil } }
        )) {
            Button("开始恢复") { performRestore() }
            Button("取消", role: .cancel) { pendingRestore = nil }
        } message: {
            if let file = pendingRestore {
                Text("备份里有 \(file.decks.count) 个词库、\(file.decks.reduce(0) { $0 + $1.words.count }) 个词。同名同 id 的词库会跳过。")
            }
        }
        .alert("重置学习进度？", isPresented: $isConfirmingReset) {
            Button("重置", role: .destructive) { performReset() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("所有词会回到「没学过」，连续的打卡记录也会清空。词库和词条本身保留。")
        }
        .alert("通知没有打开", isPresented: $reminderDenied) {
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("知道了", role: .cancel) {}
        } message: {
            Text("系统里关掉了通知权限。打开后才能收到每日提醒。")
        }
        .alert("提示", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button("好", role: .cancel) { notice = nil }
        } message: {
            Text(notice ?? "")
        }
        .alert("出错了", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 小组件

    private func labeled(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(Theme.Palette.textSecondary)
                .monospacedDigit()
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = settings.reminderHour
                components.minute = settings.reminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                settings.reminderHour = components.hour ?? 20
                settings.reminderMinute = components.minute ?? 0
                settings.updatedAt = Date()
                if settings.reminderEnabled {
                    applyReminder(enabled: true)
                }
            }
        )
    }

    // MARK: - 提醒

    private func applyReminder(enabled: Bool) {
        settings.updatedAt = Date()
        if enabled {
            Task {
                let granted = await NotificationService.shared.requestAuthorization()
                if granted {
                    await NotificationService.shared.scheduleDaily(hour: settings.reminderHour,
                                                                  minute: settings.reminderMinute)
                } else {
                    reminderDenied = true
                    settings.reminderEnabled = false
                }
            }
        } else {
            NotificationService.shared.cancel()
        }
    }

    // MARK: - 备份

    private var hasBuiltInLibrary: Bool {
        decks.contains(where: \.isBuiltIn)
    }

    private func restoreBuiltInLibrary() {
        do {
            let deck = try SeedLibrary.install(in: context)
            settings.selectedDeckID = deck.id
            try context.save()
        } catch {
            errorMessage = "恢复内置词库失败：\(error.localizedDescription)"
        }
    }

    private func prepareExport() {
        do {
            let backup = try BackupService.makeBackup(context: context)
            let data = try BackupService.encode(backup)
            exportDocument = BackupDocument(data: data)
            isExporting = true
        } catch {
            errorMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let needsRelease = url.startAccessingSecurityScopedResource()
            defer { if needsRelease { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                pendingRestore = try BackupService.decode(data)
            } catch {
                errorMessage = "读取备份失败：\(error.localizedDescription)"
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func performRestore() {
        guard let file = pendingRestore else { return }
        pendingRestore = nil
        do {
            let report = try BackupService.restore(file, into: context)
            notice = report.summary
        } catch {
            errorMessage = "恢复失败：\(error.localizedDescription)"
        }
    }

    private func performReset() {
        do {
            try BackupService.resetProgress(context: context)
            notice = "学习进度已重置。"
        } catch {
            errorMessage = "重置失败：\(error.localizedDescription)"
        }
    }
}

/// 包一层 JSON，给 fileExporter 用。
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview("设置") {
    SettingsView()
        .modelContainer(BeanManStore.makePreviewContainer())
}