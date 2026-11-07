import Foundation
import UserNotifications

/// 每日提醒。用系统本地通知，不联网、不需要账号。
///
/// 只维护**一条**通知：固定 identifier，先移除再添加，
/// 这样用户改时间不会堆积出一堆重复提醒（PRD F10）。
@MainActor
final class NotificationService {

    static let shared = NotificationService()
    static let identifier = "daily.reminder"

    private let center = UNUserNotificationCenter.current()

    /// 请求权限。第一次会弹系统框；用户拒绝过就不会再弹，直接返回 false。
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// 每天固定时间提醒。hour/minute 用本地时区。
    @discardableResult
    func scheduleDaily(hour: Int, minute: Int) async -> Bool {
        let granted = await requestAuthorization()
        guard granted else { return false }

        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])

        let content = UNMutableNotificationContent()
        content.title = "该背单词了"
        content.body = "小豆：今天的词还等着你，几分钟就好。"
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }

    /// 是否已经排上了提醒（用户可能在系统设置里关掉通知，这里只看有没有请求）。
    func hasScheduledReminder() async -> Bool {
        let requests = await center.pendingNotificationRequests()
        return requests.contains { $0.identifier == Self.identifier }
    }
}