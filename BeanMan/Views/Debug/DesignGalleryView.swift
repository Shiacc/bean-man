import SwiftUI

/// 素材自检：哪只动物有主图、哪只还缺表情。
/// 做 20 只的时候靠它一眼看出进度，不用翻文件夹。
enum AssetAudit {
    struct Row: Identifiable {
        let animal: Animal
        let missing: [AnimalExpression]
        var id: String { animal.rawValue }
        var hasMaster: Bool { !missing.contains(.normal) }
    }

    /// 只要求 `normal` 必须存在；其余表情缺失只记录不报错。
    static func rows() -> [Row] {
        Animal.allCases.map { animal in
            let missing = AnimalExpression.allCases.filter { !animal.isAvailable($0) }
            return Row(animal: animal, missing: missing)
        }
    }

    static func summary() -> (ready: Int, missingMaster: Int) {
        let rows = rows()
        return (rows.filter(\.hasMaster).count, rows.filter { !$0.hasMaster }.count)
    }
}

/// 设计验收页：气泡、动物、引导动画都能在这里直接点。
/// 入口在「设置」tab → 设计验收。真机/模拟器都能用，不依赖后端。
@MainActor
struct DesignGalleryView: View {
    @State private var frames: [String: CGRect] = [:]
    @State private var demoRequest: HintRequest?

    private let center = HintCenter.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                bubbleSection
                edgeSection
                companionSection
                animalSection
                hintSection
                auditSection
            }
            .padding(.horizontal, Theme.Spacing.screenH)
            .padding(.vertical, 20)
        }
        .background(Theme.Palette.bg)
        .navigationTitle("设计验收")
        .navigationBarTitleDisplayMode(.inline)
        .onPreferenceChange(FramePreferenceKey.self) { frames = $0 }
        .overlay {
            if let request = demoRequest ?? center.current {
                let id = request.id
                if let frame = frames[id], frame.width > 1 {
                    HintOverlay(target: frame, copy: HintCopy.of(id)) {
                        if demoRequest != nil {
                            demoRequest = nil
                        } else {
                            center.dismiss()
                        }
                    }
                }
            }
        }
    }

    // MARK: 气泡 · 语气

    private var bubbleSection: some View {
        section("气泡 · 五种语气") {
            VStack(alignment: .leading, spacing: 14) {
                row(.brand, "小豆小豆，今天 12 个到期词在等你")
                row(.success, "这个记住了，下次 25 天后再见")
                row(.warning, "还有 20 个没看，别急着一次看完")
                row(.danger, "这个已经错了三次，要不要记一下")
                row(.neutral, "长按词条可以收藏到生词本")
            }
        }
    }

    private func row(_ tone: BubbleTone, _ line: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(tone.accent.opacity(0.85))
                .frame(width: 36, height: 36)
                .overlay(
                    Text("豆")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                )
            XiaodouSpeech(line: line, tone: tone)
        }
    }

    // MARK: 气泡 · 尾巴方向

    private var edgeSection: some View {
        section("气泡 · 尾巴方向") {
            VStack(spacing: 18) {
                HStack(alignment: .top, spacing: 8) {
                    tag("leading")
                    XiaodouSpeech(line: "尾巴在左边，指向说话的人")
                }
                HStack(alignment: .top, spacing: 8) {
                    XiaodouSpeech(line: "尾巴在右边，指向右侧对象", edge: .trailing)
                    tag("trailing")
                }
                XiaodouSpeech(line: "尾巴在上，指向上一行", edge: .top)
                XiaodouSpeech(line: "尾巴在下，指向下一行", edge: .bottom)
            }
        }
    }

    // MARK: 组合

    private var companionSection: some View {
        section("小动物 + 气泡") {
            VStack(alignment: .leading, spacing: 18) {
                CompanionBubble(
                    animal: .juzi,
                    line: "小豆小豆，今天 12 个到期词在等你",
                    detail: "先清到期，再学 20 个新词"
                )
                CompanionBubble(
                    animal: .juzi,
                    line: "这个记住了",
                    expression: .happy,
                    tone: .success
                )
                CompanionBubble(
                    animal: .juzi,
                    line: "慢慢来，一次过 10 张就很好",
                    expression: .blink,
                    tone: .warning
                )
            }
        }
    }

    // MARK: 动物矩阵

    private var animalSection: some View {
        section("小动物 · 表情矩阵") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    ForEach(AnimalExpression.allCases, id: \.self) { expr in
                        Text(expr.rawValue)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Palette.textTertiary)
                            .frame(width: 56)
                    }
                }
                ForEach(Animal.allCases) { animal in
                    HStack(spacing: 8) {
                        ForEach(AnimalExpression.allCases, id: \.self) { expr in
                            AnimalView(animal: animal, size: 56, expression: expr, animated: false)
                                .frame(width: 56, height: 56)
                                .opacity(animal.isAvailable(expr) ? 1 : 0.35)
                        }
                        Spacer(minLength: 6)
                        Text(animal.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: 引导

    private var hintSection: some View {
        section("引导动画") {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    demoRequest = HintRequest(id: HintID.todayStartStudy, priority: 10)
                } label: {
                    Text("演示：开始学习（本地演示，不写记录）")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Palette.brand)
                .captureFrame(HintID.todayStartStudy)

                Button {
                    center.request(HintCopy.request(HintID.todayStatTiles))
                } label: {
                    Text("演示：统计三连（走 HintCenter，只显示一次）")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Palette.brand)
                .captureFrame(HintID.todayStatTiles)

                Button {
                    center.request(HintCopy.request(HintID.studyFlipCard))
                } label: {
                    Text("演示：翻卡片（走 HintCenter，只显示一次）")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Palette.brand)
                .captureFrame(HintID.studyFlipCard)

                Button("重置所有提示记录", role: .destructive) {
                    center.resetAll()
                }
                .font(.system(size: 14, weight: .medium))
            }
        }
    }

    // MARK: 自检

    private var auditSection: some View {
        let rows = AssetAudit.rows()
        let summary = AssetAudit.summary()
        return section("素材自检") {
            VStack(alignment: .leading, spacing: 10) {
                Text("主图齐全 \(summary.ready) / \(rows.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(summary.missingMaster == 0 ? Theme.Palette.success : Theme.Palette.warning)

                ForEach(rows) { row in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(row.hasMaster ? Theme.Palette.success : Theme.Palette.textTertiary)
                            .frame(width: 6, height: 6)
                        Text(row.animal.displayName)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .frame(width: 64, alignment: .leading)
                        Text(row.missing.isEmpty ? "表情齐全" : "缺 " + row.missing.map(\.rawValue).joined(separator: " / "))
                            .font(.system(size: 12))
                            .foregroundStyle(row.missing.isEmpty ? Theme.Palette.textTertiary : Theme.Palette.warning)
                    }
                }
            }
        }
    }

    // MARK: 小工具

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Palette.textTertiary)
                .textCase(.uppercase)
            content()
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.Palette.textTertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Theme.Palette.surfaceAlt, in: Capsule())
    }
}

/// 设置 tab 的过渡页：第二阶段会把真正的设置项填进来，先留一个验收入口。
@MainActor
struct SettingsStubView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    DesignGalleryView()
                } label: {
                    Label("设计验收", systemImage: "paintpalette")
                }
            } header: {
                Text("开发者")
            } footer: {
                Text("气泡、动物、引导动画都在这里点得到。")
            }

            Section("第二阶段") {
                Text("每日新词数、复习上限、提醒时间、发音口音、数据导出与重置，会在第二阶段补齐。")
                    .font(Theme.Font.bodySmall)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .navigationTitle("设置")
    }
}

#Preview("设计验收") {
    NavigationStack {
        DesignGalleryView()
    }
}