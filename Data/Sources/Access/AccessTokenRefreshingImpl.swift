import Core
import Foundation

public struct AccessTokenRefreshingImpl: AccessTokenRefreshing {
    private let client: any NetClient
    private let baseURL: URL

    public init(client: any NetClient, baseURL: URL) {
        self.client = client
        self.baseURL = baseURL
    }

    public func refresh(refreshToken: String) async throws(AuthError) -> AuthTokens {
        let body = RefreshRequestBody(refreshToken: refreshToken)
        let request = NetRequest.Builder()
            .url(
                baseURL
                    .appendingPathComponent("users")
                    .appendingPathComponent("refresh-token")
                    .absoluteString
            )
            .method(.post)
            .body(.json(body))
            .shouldCache(false)
            .build()
        do {
            let response: FreeAPIEnvelope<RefreshDataDTO> = try await client.request(request)
            return AuthTokens(
                accessToken: response.data.accessToken,
                refreshToken: response.data.refreshToken,
                accessTokenExpiresAt: JWTExpiry.expirationDate(of: response.data.accessToken)
            )
        } catch {
            throw AuthError.underlying(error)
        }
    }
}
