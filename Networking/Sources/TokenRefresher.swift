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
            return try await refreshTokens(replacing: tokens.accessToken).accessToken
        }
        return tokens.accessToken
    }

    /// Refreshes the stored tokens via the network.
    ///
    /// - Parameter staleAccessToken: The specific access token the caller considers
    ///   outdated. When provided, the method first re-reads the store to detect
    ///   whether a concurrent refresh already replaced it: if the stored token
    ///   differs, the fresh token is returned immediately without a second network
    ///   call. Pass `nil` (the default) to force a refresh unconditionally — this
    ///   is the right choice for the 401-retry path, where the caller does not know
    ///   whether a sibling refresh already ran.
    @discardableResult
    public func refreshTokens(replacing staleAccessToken: String? = nil) async throws(TokenError) -> AuthTokens {
        if let task = inFlight {
            do {
                return try await task.value
            } catch {
                throw .refreshFailed
            }
        }

        // Guard against the actor re-entrancy edge case:
        //
        // A caller can load expired tokens inside currentValidAccessToken(), then
        // suspend at that await point while another refresh (T1) completes — setting
        // inFlight back to nil and saving fresh tokens — before the caller ever
        // reaches this method. Without this check the caller would kick off T2,
        // a redundant refresh against already-valid tokens.
        //
        // By re-reading the store here and comparing access tokens, we detect that
        // situation and return the already-fresh token. We also re-check inFlight
        // after the await in case a concurrent caller raced us to start a new task.
        if let staleAccessToken {
            guard let current = await tokenStore.load() else {
                await onTokensInvalidated?()
                throw .notAuthenticated
            }
            if let task = inFlight {
                do {
                    return try await task.value
                } catch {
                    throw .refreshFailed
                }
            }
            if current.accessToken != staleAccessToken {
                return current
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
