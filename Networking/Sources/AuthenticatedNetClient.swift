import Core
import Foundation

public struct AuthenticatedNetClient: NetClient {
    private let base: any NetClient
    private let refresher: TokenRefresher

    public init(base: any NetClient, refresher: TokenRefresher) {
        self.base = base
        self.refresher = refresher
    }

    public func request(_ request: NetRequest) async throws -> NetworkResponse {
        try await send(request) { try await base.request($0) }
    }

    public func request<T: Decodable & Sendable>(_ request: NetRequest) async throws -> T {
        try await send(request) { try await base.request($0) }
    }

    public func upload(
        _ request: NetRequest,
        archives: [FormData],
        jsonKey: String,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> NetworkResponse {
        try await send(request) {
            try await base.upload($0, archives: archives, jsonKey: jsonKey, progress: progress)
        }
    }

    public func cancelAllTasks() {
        base.cancelAllTasks()
    }

    private func send<T: Sendable>(
        _ request: NetRequest,
        perform: @Sendable (NetRequest) async throws -> T
    ) async throws -> T {
        let accessToken = try await refresher.currentValidAccessToken()
        let authorized = Self.authorize(request, with: accessToken)
        do {
            return try await perform(authorized)
        } catch let error as NetError {
            guard case let .http(status, _, _) = error, status == 401 else { throw error }
            let refreshed = try await refresher.refreshTokens()
            let retried = Self.authorize(request, with: refreshed.accessToken)
            return try await perform(retried)
        }
    }

    private static func authorize(_ request: NetRequest, with accessToken: String) -> NetRequest {
        let builder = NetRequest.Builder()
            .url(request.url)
            .method(request.method)
            .headers(request.headers)
            .queryItems(request.queryItems)
            .body(request.body)
            .shouldCache(request.shouldCache)
            .header(name: "Authorization", value: "Bearer \(accessToken)")
        return builder.build()
    }
}
