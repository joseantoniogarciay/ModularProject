import Core
import Foundation

@MainActor
final class AuthSessionImpl: AuthSession {
    private let tokenStore: any TokenStore
    private let accessRepository: any AccessRepository
    private let userRepository: any UserRepository

    private var continuations: [UUID: AsyncStream<AuthState>.Continuation] = [:]

    private(set) var authState: AuthState = .unknown {
        didSet { broadcast(authState) }
    }

    init(
        tokenStore: any TokenStore,
        accessRepository: any AccessRepository,
        userRepository: any UserRepository
    ) {
        self.tokenStore = tokenStore
        self.accessRepository = accessRepository
        self.userRepository = userRepository
    }

    func authStates() -> AsyncStream<AuthState> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.yield(authState)
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.continuations.removeValue(forKey: id) }
            }
        }
    }

    func restore() async {
        guard case .unknown = authState else { return }
        guard await tokenStore.load() != nil else {
            authState = .anonymous(.initial)
            return
        }
        do {
            let user = try await userRepository.currentUser()
            authState = .authenticated(user)
        } catch {
            await tokenStore.clear()
            authState = .anonymous(.sessionExpired)
        }
    }

    func login(identifier: String, password: String) async throws(LoginError) {
        let result = try await accessRepository.login(identifier: identifier, password: password)
        await tokenStore.save(result.tokens)
        authState = .authenticated(result.user)
    }

    func register(username: String, email: String, password: String) async throws(SignUpError) {
        do {
            _ = try await accessRepository.register(
                username: username, email: email, password: password
            )
        } catch {
            switch error {
            case .noConnection:           throw .noConnection
            case .usernameOrEmailTaken:   throw .usernameOrEmailTaken
            case .unknown(let cause):     throw .unknown(cause)
            }
        }
        do {
            try await login(identifier: email, password: password)
        } catch {
            throw .autoLoginFailed(error)
        }
    }

    func refreshCurrentUser() async throws(CurrentUserError) {
        let user = try await userRepository.currentUser()
        authState = .authenticated(user)
    }

    func logout() async {
        await tokenStore.clear()
        authState = .anonymous(.userLoggedOut)
    }

    func expireSession() async {
        await tokenStore.clear()
        authState = .anonymous(.sessionExpired)
    }

    private func broadcast(_ authState: AuthState) {
        for continuation in continuations.values {
            continuation.yield(authState)
        }
    }
}
