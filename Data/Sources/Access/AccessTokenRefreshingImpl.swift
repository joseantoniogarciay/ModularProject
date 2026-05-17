import Core
import Foundation

public struct AccessTokenRefreshingImpl: AccessTokenRefreshing {
    private let client: any NetClient
    private let baseURL: URL

    public init(client: any NetClient, baseURL: URL) {
        self.client = client
        self.baseURL = baseURL
    }

    public func refresh(refreshToken: String) async throws(RefreshError) -> AuthTokens {
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
        } catch let error as NetError {
            if case .noConnection = error { throw .noConnection }
            if case let .http(status, _, _) = error, status == 401 || status == 403 {
                throw .refreshTokenInvalid
            }
            throw .unknown(error)
        } catch {
            throw .unknown(error)
        }
    }
}
