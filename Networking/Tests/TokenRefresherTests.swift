import Core
import Foundation
import XCTest

@testable import Networking

// MARK: - Test doubles
//
// Mocks use @unchecked Sendable to satisfy the protocols' `: Sendable` constraint.
// Invariant: each instance is driven by at most one TokenRefresher under test;
// all assertions run after the last async operation completes. There is no
// concurrent mutation from multiple tests.

/// Immediate-response spy. Counts calls, returns a configurable stub.
final class SpyTokenRefreshing: AccessTokenRefreshing, @unchecked Sendable {
    var callCount = 0
    var stubbedTokens = AuthTokens(
        accessToken: "fresh_access",
        refreshToken: "fresh_refresh",
        accessTokenExpiresAt: nil
    )
    var stubbedError: RefreshError?

    func refresh(refreshToken: String) async throws(RefreshError) -> AuthTokens {
        callCount += 1
        if let error = stubbedError { throw error }
        return stubbedTokens
    }
}

/// Suspending spy. Blocks inside refresh() until resume() is called from the
/// test, giving concurrent callers time to queue up in the TokenRefresher actor.
/// resume() must be called exactly once after each blocked refresh().
final class SuspendingTokenRefreshing: AccessTokenRefreshing, @unchecked Sendable {
    // Invariant: continuation is set synchronously inside withCheckedContinuation's
    // body (which runs before the suspension) and is read from resume(), which is
    // always called from the test *after* refresh() has suspended. No overlapping
    // writes or reads; @unchecked Sendable is safe here.
    var callCount = 0
    let stubbedTokens = AuthTokens(
        accessToken: "fresh_access",
        refreshToken: "fresh_refresh",
        accessTokenExpiresAt: nil
    )
    private var continuation: CheckedContinuation<AuthTokens, Never>?

    func refresh(refreshToken: String) async throws(RefreshError) -> AuthTokens {
        callCount += 1
        return await withCheckedContinuation { cont in
            self.continuation = cont
        }
    }

    func resume() {
        continuation?.resume(returning: stubbedTokens)
        continuation = nil
    }
}

/// Box that lets a @Sendable closure signal back to the test without capturing
/// a `var` — which is forbidden under strict concurrency.
/// Invariant: written from one closure (the invalidation handler) and read once
/// after the awaited operation completes; there is no concurrent mutation.
final class BoolBox: @unchecked Sendable {
    var value = false
}

/// In-memory token store with observable side-effects.
final class SpyTokenStore: TokenStore, @unchecked Sendable {
    var storedTokens: AuthTokens?
    var saveCallCount = 0
    var clearCallCount = 0

    init(tokens: AuthTokens? = nil) { storedTokens = tokens }

    func load() async -> AuthTokens? { storedTokens }
    func save(_ tokens: AuthTokens) async { storedTokens = tokens; saveCallCount += 1 }
    func clear() async { storedTokens = nil; clearCallCount += 1 }
}

// MARK: - Fixtures

private extension AuthTokens {
    /// Token that appears stale under the default 60-second proactive leeway.
    static func expiredSoon(accessToken: String = "stale_access") -> AuthTokens {
        AuthTokens(
            accessToken: accessToken,
            refreshToken: "refresh",
            accessTokenExpiresAt: Date(timeIntervalSinceNow: 30) // within 60s leeway
        )
    }

    /// Token with plenty of time left — will NOT trigger a proactive refresh.
    static func fresh(accessToken: String = "fresh_access") -> AuthTokens {
        AuthTokens(
            accessToken: accessToken,
            refreshToken: "refresh",
            accessTokenExpiresAt: Date(timeIntervalSinceNow: 300)
        )
    }

    /// Token with no expiry date — treated as always valid by currentValidAccessToken.
    static func noExpiry(accessToken: String = "access") -> AuthTokens {
        AuthTokens(accessToken: accessToken, refreshToken: "refresh", accessTokenExpiresAt: nil)
    }
}

// MARK: - TokenRefresherTests

final class TokenRefresherTests: XCTestCase {

    // MARK: currentValidAccessToken — happy paths

    func testCurrentValidAccessToken_freshToken_returnedWithoutRefresh() async throws {
        let store = SpyTokenStore(tokens: .fresh(accessToken: "valid"))
        let spy = SpyTokenRefreshing()
        let sut = TokenRefresher(tokenStore: store, tokenRefreshing: spy)

        let token = try await sut.currentValidAccessToken()

        XCTAssertEqual(token, "valid")
        XCTAssertEqual(spy.callCount, 0, "A non-expired token must not trigger a network refresh")
    }

    func testCurrentValidAccessToken_noExpiry_returnedWithoutRefresh() async throws {
        let store = SpyTokenStore(tokens: .noExpiry(accessToken: "no-exp"))
        let spy = SpyTokenRefreshing()
        let sut = TokenRefresher(tokenStore: store, tokenRefreshing: spy)

        let token = try await sut.currentValidAccessToken()

        XCTAssertEqual(token, "no-exp")
        XCTAssertEqual(spy.callCount, 0)
    }

    func testCurrentValidAccessToken_noToken_throwsNotAuthenticated() async {
        let store = SpyTokenStore(tokens: nil)
        let sut = TokenRefresher(tokenStore: store, tokenRefreshing: SpyTokenRefreshing())

        do {
            _ = try await sut.currentValidAccessToken()
            XCTFail("Expected TokenError.notAuthenticated")
        } catch {
            guard case .notAuthenticated = error else {
                XCTFail("Expected .notAuthenticated, got \(error)"); return
            }
        }
    }

    func testCurrentValidAccessToken_tokenWithinLeeway_refreshesAndReturnsNewToken() async throws {
        let spy = SpyTokenRefreshing()
        spy.stubbedTokens = .fresh(accessToken: "refreshed")
        let store = SpyTokenStore(tokens: .expiredSoon())
        let sut = TokenRefresher(tokenStore: store, tokenRefreshing: spy)

        let token = try await sut.currentValidAccessToken()

        XCTAssertEqual(token, "refreshed")
        XCTAssertEqual(spy.callCount, 1)
    }

    // MARK: refreshTokens — coalescing

    /// Verifies that concurrent refreshTokens() calls while one is in-flight
    /// all coalesce onto the single underlying network request.
    func testRefreshTokens_concurrentCalls_coalescedIntoSingleNetworkRequest() async throws {
        let store = SpyTokenStore(tokens: .noExpiry(accessToken: "old"))
        let suspending = SuspendingTokenRefreshing()
        let sut = TokenRefresher(tokenStore: store, tokenRefreshing: suspending)

        // Launch 5 concurrent refresh calls as unstructured tasks so they pile up
        // on the TokenRefresher actor while the first refresh is blocked.
        let tasks = (0..<5).map { _ in
            Task<AuthTokens?, Never> { try? await sut.refreshTokens() }
        }

        // Yield enough times for all tasks to reach their suspension points inside
        // the TokenRefresher actor and coalesce onto the in-flight task.
        for _ in 0..<10 { await Task.yield() }

        // Unblock the one network call that should have been made.
        suspending.resume()

        let results = await withTaskGroup(of: AuthTokens?.self) { group in
            for task in tasks { group.addTask { await task.value } }
            var collected: [AuthTokens?] = []
            for await r in group { collected.append(r) }
            return collected
        }

        XCTAssertEqual(suspending.callCount, 1, "All concurrent refresh calls must coalesce into one network request")
        let tokens = results.compactMap(\.?.accessToken)
        XCTAssertEqual(tokens.count, 5, "Every caller must receive a token")
        XCTAssertTrue(tokens.allSatisfy { $0 == "fresh_access" }, "Every caller must receive the same fresh token")
    }

    // MARK: refreshTokens(replacing:) — edge case guard

    /// The fix: if the caller loaded a stale token but a concurrent refresh already
    /// completed and saved a new one, refreshTokens(replacing:) must detect this by
    /// re-reading the store and return the fresh token without a second network call.
    func testRefreshTokens_replacing_storeAlreadyHasFreshToken_returnsItWithoutNetworkCall() async throws {
        // Simulate T1 already completed: store now holds the fresh token.
        let store = SpyTokenStore(tokens: .noExpiry(accessToken: "fresh_from_T1"))
        let spy = SpyTokenRefreshing()
        let sut = TokenRefresher(tokenStore: store, tokenRefreshing: spy)

        // This caller loaded "stale_access" earlier (before T1 ran) and is now
        // trying to replace it — but T1 already did.
        let result = try await sut.refreshTokens(replacing: "stale_access")

        XCTAssertEqual(result.accessToken, "fresh_from_T1")
        XCTAssertEqual(spy.callCount, 0, "Must not hit the network when the stale token was already replaced")
    }

    /// If the store still holds the same stale token (no concurrent refresh happened),
    /// refreshTokens(replacing:) must proceed with the real network call.
    func testRefreshTokens_replacing_tokenStillStale_performsRefresh() async throws {
        let store = SpyTokenStore(tokens: .noExpiry(accessToken: "stale_access"))
        let spy = SpyTokenRefreshing()
        spy.stubbedTokens = .noExpiry(accessToken: "fresh_access")
        let sut = TokenRefresher(tokenStore: store, tokenRefreshing: spy)

        let result = try await sut.refreshTokens(replacing: "stale_access")

        XCTAssertEqual(result.accessToken, "fresh_access")
        XCTAssertEqual(spy.callCount, 1)
    }

    /// Without a replacing token (401 path), refreshTokens() always refreshes,
    /// even if the store appears to hold a fresh-looking token.
    func testRefreshTokens_noReplacingToken_alwaysRefreshes() async throws {
        let store = SpyTokenStore(tokens: .fresh(accessToken: "looks_fresh"))
        let spy = SpyTokenRefreshing()
        let sut = TokenRefresher(tokenStore: store, tokenRefreshing: spy)

        _ = try await sut.refreshTokens() // no replacing: argument → 401 path

        XCTAssertEqual(spy.callCount, 1, "refreshTokens() with no replacing: must always call the network")
    }

    /// Symmetry check: refreshTokens(replacing:) returns early only when the stored
    /// token *differs* from the stale one, not when they are equal.
    func testRefreshTokens_replacing_storedTokenMatchesStale_refreshes() async throws {
        let store = SpyTokenStore(tokens: .noExpiry(accessToken: "same"))
        let spy = SpyTokenRefreshing()
        let sut = TokenRefresher(tokenStore: store, tokenRefreshing: spy)

        _ = try await sut.refreshTokens(replacing: "same")

        XCTAssertEqual(spy.callCount, 1)
    }

    // MARK: refreshTokens — failure & invalidation

    func testRefreshTokens_networkFailure_clearsStoreAndCallsInvalidatedHandler() async throws {
        let store = SpyTokenStore(tokens: .noExpiry())
        let spy = SpyTokenRefreshing()
        spy.stubbedError = .refreshTokenInvalid
        let sut = TokenRefresher(tokenStore: store, tokenRefreshing: spy)

        let invalidated = BoolBox()
        await sut.setOnTokensInvalidated { invalidated.value = true }

        do {
            _ = try await sut.refreshTokens()
            XCTFail("Expected TokenError.refreshFailed")
        } catch {
            guard case .refreshFailed = error else {
                XCTFail("Expected .refreshFailed, got \(error)"); return
            }
        }

        XCTAssertGreaterThanOrEqual(store.clearCallCount, 1, "Store must be cleared on refresh failure")
        XCTAssertTrue(invalidated.value, "onTokensInvalidated must fire on refresh failure")
    }

    func testRefreshTokens_replacing_noTokenInStore_throwsNotAuthenticated() async {
        let store = SpyTokenStore(tokens: nil)
        let sut = TokenRefresher(tokenStore: store, tokenRefreshing: SpyTokenRefreshing())

        do {
            _ = try await sut.refreshTokens(replacing: "stale")
            XCTFail("Expected TokenError.notAuthenticated")
        } catch {
            guard case .notAuthenticated = error else {
                XCTFail("Expected .notAuthenticated, got \(error)"); return
            }
        }
    }

    // MARK: invalidate

    func testInvalidate_clearsStoreAndCallsHandler() async {
        let store = SpyTokenStore(tokens: .noExpiry())
        let sut = TokenRefresher(tokenStore: store, tokenRefreshing: SpyTokenRefreshing())
        let invalidated = BoolBox()
        await sut.setOnTokensInvalidated { invalidated.value = true }

        await sut.invalidate()

        XCTAssertEqual(store.clearCallCount, 1)
        XCTAssertTrue(invalidated.value)
    }
}
