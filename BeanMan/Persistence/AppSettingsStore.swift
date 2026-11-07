import Foundation
import SwiftData

/// AppSettings 的读取/创建。用 `key = "app"` 单例。
enum AppSettingsStore {

    static func settings(in context: ModelContext) throws -> AppSettings? {
        var descriptor = FetchDescriptor<AppSettings>(predicate: #Predicate<AppSettings> { $0.key == "app" })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// 取设置，没有就建一个（首次启动 / 内存库预览都会走到）。
    @discardableResult
    static func current(in context: ModelContext) throws -> AppSettings {
        if let existing = try settings(in: context) { return existing }
        let created = AppSettings()
        context.insert(created)
        try context.save()
        return created
    }

    static func markUpdated(_ settings: AppSettings) {
        settings.updatedAt = Date()
    }
}