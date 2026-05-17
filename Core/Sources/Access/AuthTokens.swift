import Foundation

public struct AuthTokens: Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let accessTokenExpiresAt: Date?

    public init(accessToken: String, refreshToken: String, accessTokenExpiresAt: Date?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accessTokenExpiresAt = accessTokenExpiresAt
    }
}
