import Core
import Foundation

public struct AccessRepositoryImpl: AccessRepository {
    private let client: any NetClient
    private let baseURL: URL

    public init(client: any NetClient, baseURL: URL) {
        self.client = client
        self.baseURL = baseURL
    }

    public func login(identifier: String, password: String) async throws(LoginError) -> LoginResult {
        let isEmail = identifier.contains("@")
        let body = LoginRequestBody(
            email: isEmail ? identifier : nil,
            username: isEmail ? nil : identifier,
            password: password
        )
        let request = NetRequest.Builder()
            .url(
                baseURL
                    .appendingPathComponent("users")
                    .appendingPathComponent("login")
                    .absoluteString
            )
            .method(.post)
            .body(.json(body))
            .shouldCache(false)
            .build()
        do {
            let response: FreeAPIEnvelope<LoginDataDTO> = try await client.request(request)
            let tokens = AuthTokens(
                accessToken: response.data.accessToken,
                refreshToken: response.data.refreshToken,
                accessTokenExpiresAt: JWTExpiry.expirationDate(of: response.data.accessToken)
            )
            return LoginResult(user: response.data.user.toDomain(), tokens: tokens)
        } catch let error as NetError {
            if case .noConnection = error { throw .noConnection }
            if case let .http(status, _, _) = error, status == 401 || status == 400 || status == 404 {
                throw .invalidCredentials
            }
            throw .unknown(error)
        } catch {
            throw .unknown(error)
        }
    }

    public func register(username: String, email: String, password: String) async throws(RegisterError) -> User {
        let body = RegisterRequestBody(email: email, username: username, password: password, role: "USER")
        let request = NetRequest.Builder()
            .url(
                baseURL
                    .appendingPathComponent("users")
                    .appendingPathComponent("register")
                    .absoluteString
            )
            .method(.post)
            .body(.json(body))
            .shouldCache(false)
            .build()
        do {
            let response: FreeAPIEnvelope<RegisterDataDTO> = try await client.request(request)
            return response.data.user.toDomain()
        } catch let error as NetError {
            if case .noConnection = error { throw .noConnection }
            if case let .http(status, _, _) = error, status == 409 || status == 400 {
                throw .usernameOrEmailTaken
            }
            throw .unknown(error)
        } catch {
            throw .unknown(error)
        }
    }
}
