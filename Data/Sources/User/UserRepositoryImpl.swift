import Core
import Foundation

public struct UserRepositoryImpl: UserRepository {
    private let client: any NetClient
    private let baseURL: URL

    public init(client: any NetClient, baseURL: URL) {
        self.client = client
        self.baseURL = baseURL
    }

    public func currentUser() async throws(AuthError) -> User {
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
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.underlying(error)
        }
    }
}
