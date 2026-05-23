import Core
import Foundation

public actor TokenRefresher {
    private let tokenStore: any TokenStore
    private let tokenRefreshing: any AccessTokenRefreshing
    private let proactiveLeeway: TimeInterval
    private let now: @Sendable () -> Date
    private var inFlight: Task<AuthTokens, any Error>?
    private var onTokensInvalidated: (@Sendable () async -> Void)?

    public init(
        tokenStore: any TokenStore,
        tokenRefreshing: any AccessTokenRefreshing,
        proactiveLeeway: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.tokenStore = tokenStore
        self.tokenRefreshing = tokenRefreshing
        self.proactiveLeeway = proactiveLeeway
        self.now = now
    }

    public func setOnTokensInvalidated(_ handler: @escaping @Sendable () async -> Void) {
        self.onTokensInvalidated = handler
    }

    public func invalidate() async {
        await tokenStore.clear()
        await onTokensInvalidated?()
    }

    public func currentValidAccessToken() async throws(TokenError) -> String {
        guard let tokens = await tokenStore.load() else {
            await onTokensInvalidated?()
            throw .notAuthenticated
        }
        if let expiresAt = tokens.accessTokenExpiresAt,
           expiresAt.timeIntervalSince(now()) <= proactiveLeeway {
            return try await refreshTokens().accessToken
        }
        return tokens.accessToken
    }

    @discardableResult
    public func refreshTokens() async throws(TokenError) -> AuthTokens {
        if let task = inFlight {
            do {
                return try await task.value
            } catch {
                throw .refreshFailed
            }
        }
        let task = Task { [tokenStore, tokenRefreshing] in
            try await Self.performRefresh(tokenStore: tokenStore, tokenRefreshing: tokenRefreshing)
        }
        inFlight = task
        do {
            let result = try await task.value
            inFlight = nil
            return result
        } catch {
            inFlight = nil
            await onTokensInvalidated?()
            throw .refreshFailed
        }
    }

    private static func performRefresh(
        tokenStore: any TokenStore,
        tokenRefreshing: any AccessTokenRefreshing
    ) async throws -> AuthTokens {
        guard let tokens = await tokenStore.load() else {
            throw TokenError.notAuthenticated
        }
        do {
            let refreshed = try await tokenRefreshing.refresh(refreshToken: tokens.refreshToken)
            await tokenStore.save(refreshed)
            return refreshed
        } catch {
            await tokenStore.clear()
            throw TokenError.refreshFailed
        }
    }
}
