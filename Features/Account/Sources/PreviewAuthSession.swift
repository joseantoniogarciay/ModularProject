#if DEBUG
import Core
import Foundation

@MainActor
final class PreviewAuthSession: AuthSession {
    var authState: AuthState = .anonymous(.initial)

    func authStates() -> AsyncStream<AuthState> {
        AsyncStream { continuation in
            continuation.yield(self.authState)
        }
    }

    func restore() async {}
    func login(identifier: String, password: String) async throws(LoginError) {}
    func register(username: String, email: String, password: String) async throws(SignUpError) {}
    func refreshCurrentUser() async throws(CurrentUserError) {}
    func logout() async {}
    func expireSession() async {}
}
#endif
