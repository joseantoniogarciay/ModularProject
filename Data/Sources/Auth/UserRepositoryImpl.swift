import Core
import Foundation

public struct UserRepositoryImpl: UserRepository {
    private let client: any NetClient
    private let baseURL: URL

    public init(client: any NetClient, baseURL: URL) {
        self.client = client
        self.baseURL = baseURL
    }

    public func currentUser() async throws -> User {
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
        let response: FreeAPIEnvelope<UserDTO> = try await client.request(request)
        return response.data.toDomain()
    }
}
