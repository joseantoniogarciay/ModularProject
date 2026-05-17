import Foundation

public struct LoginResult: Sendable {
    public let user: User
    public let tokens: AuthTokens

    public init(user: User, tokens: AuthTokens) {
        self.user = user
        self.tokens = tokens
    }
}

public protocol AuthRepository: Sendable {
    func login(identifier: String, password: String) async throws -> LoginResult
    func register(username: String, email: String, password: String) async throws -> User
    func refresh(refreshToken: String) async throws -> AuthTokens
}

public protocol UserRepository: Sendable {
    func currentUser() async throws -> User
}
