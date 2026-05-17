import Foundation

public struct User: Sendable {
    public let id: String
    public let username: String
    public let email: String
    public let role: String?
    public let avatarURL: URL?

    public init(id: String, username: String, email: String, role: String?, avatarURL: URL?) {
        self.id = id
        self.username = username
        self.email = email
        self.role = role
        self.avatarURL = avatarURL
    }
}
