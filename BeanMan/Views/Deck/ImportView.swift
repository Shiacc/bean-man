import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 导入词库：选 CSV 文件，或者直接粘贴表格文本。
@MainActor
struct ImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// 导入成功后回传词库 id，让外面自动选中它
    var onImported: (UUID) -> Void = { _ in }

    private enum Source: String, CaseIterable, Identifiable {
        case file = "选择文件"
        case paste = "粘贴文本"
        var id: String { rawValue }
    }

    @State private var source: Source = .file
    @State private var deckName = ""
    @State private var appendToCurrent = false
    @State private var pastedText = ""
    @State private var isPickingFile = false
    @State private var isLoadingFile = false
    @State private var report: ImportReport?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("词库名，例如「托福核心」", text: $deckName)
                        .disabled(appendToCurrent)
                    Toggle("追加到当前词库", isOn: $appendToCurrent)
                        .disabled(currentDeck == nil)
                } header: {
                    Text("导入到")
                } footer: {
                    Text(appendToCurrent
                         ? "会追加到「\(currentDeck?.name ?? "当前词库")」，重复的词自动跳过。"
                         : "会新建一个词库，并自动设为当前词库。")
                        .font(Theme.Font.caption)
                }

                Section {
                    Picker("来源", selection: $source) {
                        ForEach(Source.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    switch source {
                    case .file:
                        Button {
                            isPickingFile = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "doc.badge.plus")
                                    .foregroundStyle(Theme.Palette.brand)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("选择 CSV 文件")
                                        .foregroundStyle(Theme.Palette.textPrimary)
                                    Text("表头需包含 word 与 meaning 两列")
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(Theme.Palette.textSecondary)
                                }
                                Spacer()
                                if isLoadingFile {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.Palette.textTertiary)
                                }
                            }
                        }
                        .disabled(isLoadingFile)
                    case .paste:
                        TextEditor(text: $pastedText)
                            .frame(minHeight: 160)
                            .font(.system(size: 13, design: .monospaced))
                            .overlay(alignment: .topLeading) {
                                if pastedText.isEmpty {
                                    Text("word,phonetic,partOfSpeech,meaning\nabandon,/əˈbændən/,v.,放弃；抛弃")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(Theme.Palette.textTertiary)
                                        .padding(.top, 8)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                } header: {
                    Text("CSV 内容")
                } footer: {
                    Text("支持中英文表头；缺字段会补空；单词或释义为空的行会跳过并列出。")
                        .font(Theme.Font.caption)
                }

                if let report {
                    Section {
                        reportCard(report)
                    }
                }

                Section {
                    Button {
                        startImport()
                    } label: {
                        Text("开始导入")
                            .font(Theme.Font.button)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(enabled: canImport))
                    .disabled(!canImport)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.bg)
            .navigationTitle("导入词库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                if report != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { dismiss() }
                    }
                }
            }
            .fileImporter(isPresented: $isPickingFile,
                          allowedContentTypes: [.commaSeparatedText, .plainText, .text],
                          allowsMultipleSelection: false) { result in
                handleFile(result)
            }
            .alert("导入失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 组件

    private func reportCard(_ report: ImportReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(report.summary)
                    .font(Theme.Font.body.weight(.semibold))
                    .foregroundStyle(report.isEmpty ? Theme.Palette.danger : Theme.Palette.success)
            } icon: {
                Image(systemName: report.isEmpty ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(report.isEmpty ? Theme.Palette.danger : Theme.Palette.success)
            }

            Text("词库：\(report.deckName)")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)

            if !report.issues.isEmpty {
                Divider()
                Text("跳过的行")
                    .font(Theme.Font.caption.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                ForEach(report.issues.prefix(8)) { issue in
                    Text("第 \(issue.row) 行：\(issue.reason)")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.danger)
                }
                if report.issues.count > 8 {
                    Text("还有 \(report.issues.count - 8) 条…")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 数据

    private var currentDeck: Deck? {
        guard let settings = try? AppSettingsStore.current(in: context),
              let id = settings.selectedDeckID else { return nil }
        let decks = (try? context.fetch(FetchDescriptor<Deck>())) ?? []
        return decks.first { $0.id == id }
    }

    private var canImport: Bool {
        switch source {
        case .file:
            return false    // 文件路径导入是原子操作，选完就执行
        case .paste:
            return !pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func handleFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            loadAndImport(url)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func loadAndImport(_ url: URL) {
        isLoadingFile = true
        defer { isLoadingFile = false }

        let needsRelease = url.startAccessingSecurityScopedResource()
        defer { if needsRelease { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            guard let text = Self.decode(data) else {
                errorMessage = "文件编码认不出来，请另存为 UTF-8 后再试"
                return
            }
            run(text)
        } catch {
            errorMessage = "读取文件失败：\(error.localizedDescription)"
        }
    }

    /// UTF-8 优先，其次 GB18030（Windows 上的 Excel 常这么存）。
    static func decode(_ data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8) { return text }
        let gb = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        if let text = String(data: data, encoding: String.Encoding(rawValue: gb)) { return text }
        if let text = String(data: data, encoding: .isoLatin1) { return text }
        return nil
    }

    private func startImport() {
        run(pastedText)
    }

    private func run(_ text: String) {
        let target = appendToCurrent ? currentDeck : nil
        do {
            let result = try DeckImporter.importCSV(text: text,
                                                    deckName: deckName,
                                                    appendingTo: target,
                                                    context: context)
            report = result
            onImported(result.deckID)
            pastedText = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("导入") {
    ImportView()
        .modelContainer(BeanManStore.makePreviewContainer())
}