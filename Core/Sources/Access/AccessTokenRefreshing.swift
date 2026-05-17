import Foundation

public protocol AccessTokenRefreshing: Sendable {
    func refresh(refreshToken: String) async throws(AuthError) -> AuthTokens
}
