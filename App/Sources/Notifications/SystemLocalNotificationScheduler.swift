import Core
import UserNotifications

/// `UNUserNotificationCenter`-backed implementation of `LocalNotificationScheduling`. Lives in the
/// App layer so the system framework dependency stays out of the feature modules.
struct SystemLocalNotificationScheduler: LocalNotificationScheduling {
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func schedule(_ request: LocalNotificationRequest) async {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        content.userInfo = request.userInfo

        let unRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(unRequest)
    }
}
