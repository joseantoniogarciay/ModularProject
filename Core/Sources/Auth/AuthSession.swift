import Foundation

public enum AuthState: Sendable {
    case unknown
    case anonymous
    case authenticated(User)
}

@MainActor
public protocol AuthSession: AnyObject {
    var state: AuthState { get }
    func states() -> AsyncStream<AuthState>

    func restore() async
    func login(identifier: String, password: String) async throws
    func register(username: String, email: String, password: String) async throws
    func refreshCurrentUser() async throws
    func logout() async
}
