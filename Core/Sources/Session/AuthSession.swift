import Foundation

public enum AuthState: Sendable {
    case unknown
    case anonymous(AnonymousReason)
    case authenticated(User)
}

public enum AnonymousReason: Sendable, Equatable {
    case initial
    case userLoggedOut
    case sessionExpired
}

@MainActor
public protocol AuthSession: AnyObject {
    var authState: AuthState { get }
    func authStates() -> AsyncStream<AuthState>

    func restore() async
    func login(identifier: String, password: String) async throws(AuthError)
    func register(username: String, email: String, password: String) async throws(AuthError)
    func refreshCurrentUser() async throws(AuthError)
    func logout() async
    func expireSession() async
}
