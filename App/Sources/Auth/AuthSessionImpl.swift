import Core
import Foundation

@MainActor
final class AuthSessionImpl: AuthSession {
    private let tokenStore: any TokenStore
    private let authRepository: any AuthRepository
    private let userRepository: any UserRepository

    private var continuations: [UUID: AsyncStream<AuthState>.Continuation] = [:]

    private(set) var state: AuthState = .unknown {
        didSet { broadcast(state) }
    }

    init(
        tokenStore: any TokenStore,
        authRepository: any AuthRepository,
        userRepository: any UserRepository
    ) {
        self.tokenStore = tokenStore
        self.authRepository = authRepository
        self.userRepository = userRepository
    }

    func states() -> AsyncStream<AuthState> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.yield(state)
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.continuations.removeValue(forKey: id) }
            }
        }
    }

    func restore() async {
        guard await tokenStore.load() != nil else {
            state = .anonymous
            return
        }
        do {
            let user = try await userRepository.currentUser()
            state = .authenticated(user)
        } catch {
            await tokenStore.clear()
            state = .anonymous
        }
    }

    func login(identifier: String, password: String) async throws {
        let result = try await authRepository.login(identifier: identifier, password: password)
        await tokenStore.save(result.tokens)
        state = .authenticated(result.user)
    }

    func register(username: String, email: String, password: String) async throws {
        _ = try await authRepository.register(username: username, email: email, password: password)
        try await login(identifier: email, password: password)
    }

    func refreshCurrentUser() async throws {
        let user = try await userRepository.currentUser()
        state = .authenticated(user)
    }

    func logout() async {
        await tokenStore.clear()
        state = .anonymous
    }

    private func broadcast(_ state: AuthState) {
        for continuation in continuations.values {
            continuation.yield(state)
        }
    }
}
