import SwiftUI
import SwiftData

enum AppTab: Int, CaseIterable, Identifiable {
    case today, decks, stats, settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .today:    return "今日"
        case .decks:    return "词库"
        case .stats:    return "统计"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .today:    return "flame.fill"
        case .decks:    return "book.closed"
        case .stats:    return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}

/// 根视图：自定义底部标签栏（与 Figma `DS/TabBar` 对齐）。
/// 第二阶段会把词库 / 统计 / 设置三个页替换成真实实现，现在先占位。
struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var tab: AppTab = .today

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch tab {
                case .today:
                    TodayView()
                case .decks:
                    DeckListView()
                case .stats:
                    StatsView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .background(Theme.Palette.bg)
        .task {
            BeanManStore.bootstrap(context)
        }
    }

    private var tabBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.Palette.border)
                .frame(height: 0.5)

            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { item in
                    Button {
                        tab = item
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 20, weight: .regular))
                            Text(item.title)
                                .font(.system(size: 11, weight: tab == item ? .medium : .regular))
                        }
                        .foregroundStyle(tab == item ? Theme.Palette.brand : Theme.Palette.textTertiary)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(item.title))
                    .accessibilityAddTraits(tab == item ? [.isSelected] : [])
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .background(Theme.Palette.bg)
    }
}

/// 占位页。
struct ComingSoonView: View {
    let title: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.Font.screenTitle)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(note)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Text("第二阶段实现")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.screenH)
        .padding(.top, 40)
        .background(Theme.Palette.bg)
    }
}

#Preview {
    RootView()
        .modelContainer(BeanManStore.makePreviewContainer())
}