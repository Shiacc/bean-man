import SwiftUI
import Observation

/// 轻量路由：只负责切换底部标签。
/// 今日页里的「词库」「测试」这类跳转需要它，否则只能把闭包一层层往下传。
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab

    init(tab: AppTab = .today) {
        self.tab = tab
    }

    /// 从启动参数里读 `-startTab <today|decks|stats|settings>`。
    ///
    /// 给模拟器截图/深色校对用（CI 的 screenshots job 靠它逐页拍），正常启动时参数不存在，回落到今日页。
    static func initialTab(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppTab {
        guard let index = arguments.firstIndex(of: "-startTab"),
              arguments.indices.contains(index + 1) else { return .today }
        return AppTab(name: arguments[index + 1]) ?? .today
    }
}