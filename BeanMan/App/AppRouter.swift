import SwiftUI
import Observation

/// 轻量路由：只负责切换底部标签。
/// 今日页里的「词库」「测试」这类跳转需要它，否则只能把闭包一层层往下传。
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .today
}