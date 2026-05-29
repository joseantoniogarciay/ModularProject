import Foundation

/// A local notification described in domain terms, free of any `UserNotifications` types so the
/// contract stays in `Core` and the system framework stays out of the feature layer.
public struct LocalNotificationRequest: Sendable {
    public let identifier: String
    public let title: String
    public let body: String
    /// Payload delivered back through the notification (e.g. `["pokemon_id": 151]`) and read by
    /// the receiving side to build a deep link.
    public let userInfo: [String: Int]

    public init(identifier: String, title: String, body: String, userInfo: [String: Int]) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.userInfo = userInfo
    }
}

/// Abstracts local-notification permission and scheduling. Implemented in the App layer with
/// `UNUserNotificationCenter`; injected into features so they never import `UserNotifications`.
public protocol LocalNotificationScheduling: Sendable {
    /// Requests authorization, returning whether it is granted.
    func requestAuthorization() async -> Bool
    /// Schedules a notification for immediate delivery.
    func schedule(_ request: LocalNotificationRequest) async
}
