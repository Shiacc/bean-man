import SwiftUI

/// App 入口。数据容器在启动时建好，全局注入。
@main
struct BeanManApp: App {

    /// 真机用磁盘库；跑 Xcode Preview 时可在 RootView 里换成 `makePreviewContainer()`。
    private let container = BeanManStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.Palette.brand)
        }
        .modelContainer(container)
    }
}