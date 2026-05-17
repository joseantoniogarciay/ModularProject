import Foundation

public struct LoginResult: Sendable {
    public let user: User
    public let tokens: AuthTokens

    public init(user: User, tokens: AuthTokens) {
        self.user = user
        self.tokens = tokens
    }
}

public protocol AccessRepository: Sendable {
    func login(identifier: String, password: String) async throws(AuthError) -> LoginResult
    func register(username: String, email: String, password: String) async throws(AuthError) -> User
}
