import Core
import Foundation

public actor TokenRefresher {
    private let tokenStore: any TokenStore
    private let authRepository: any AuthRepository
    private let proactiveLeeway: TimeInterval
    private let now: @Sendable () -> Date
    private var inFlight: Task<AuthTokens, any Error>?

    public init(
        tokenStore: any TokenStore,
        authRepository: any AuthRepository,
        proactiveLeeway: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.tokenStore = tokenStore
        self.authRepository = authRepository
        self.proactiveLeeway = proactiveLeeway
        self.now = now
    }

    public func currentValidAccessToken() async throws -> String {
        guard let tokens = await tokenStore.load() else {
            throw AuthError.notAuthenticated
        }
        if let expiresAt = tokens.accessTokenExpiresAt,
           expiresAt.timeIntervalSince(now()) <= proactiveLeeway {
            return try await refreshTokens().accessToken
        }
        return tokens.accessToken
    }

    @discardableResult
    public func refreshTokens() async throws -> AuthTokens {
        if let task = inFlight {
            return try await task.value
        }
        let task = Task { [tokenStore, authRepository] in
            try await Self.performRefresh(tokenStore: tokenStore, authRepository: authRepository)
        }
        inFlight = task
        do {
            let result = try await task.value
            inFlight = nil
            return result
        } catch {
            inFlight = nil
            throw error
        }
    }

    private static func performRefresh(
        tokenStore: any TokenStore,
        authRepository: any AuthRepository
    ) async throws -> AuthTokens {
        guard let tokens = await tokenStore.load() else {
            throw AuthError.notAuthenticated
        }
        do {
            let refreshed = try await authRepository.refresh(refreshToken: tokens.refreshToken)
            await tokenStore.save(refreshed)
            return refreshed
        } catch {
            await tokenStore.clear()
            throw AuthError.refreshFailed
        }
    }
}
