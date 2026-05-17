import Core
import Foundation

public struct UserRepositoryImpl: UserRepository {
    private let client: any NetClient
    private let baseURL: URL

    public init(client: any NetClient, baseURL: URL) {
        self.client = client
        self.baseURL = baseURL
    }

    public func currentUser() async throws(CurrentUserError) -> User {
        let request = NetRequest.Builder()
            .url(
                baseURL
                    .appendingPathComponent("users")
                    .appendingPathComponent("current-user")
                    .absoluteString
            )
            .method(.get)
            .shouldCache(false)
            .build()
        do {
            let response: FreeAPIEnvelope<UserDTO> = try await client.request(request)
            return response.data.toDomain()
        } catch let error as NetError {
            if case .noConnection = error { throw .noConnection }
            if case let .http(status, _, _) = error, status == 401 { throw .notAuthenticated }
            throw .unknown(error)
        } catch is TokenError {
            throw .notAuthenticated
        } catch {
            throw .unknown(error)
        }
    }
}
