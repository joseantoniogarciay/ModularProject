import Core
import Foundation

public struct CartRepositoryImpl: CartRepository {
    private let client: any NetClient
    private let baseURL: URL

    public init(client: any NetClient, baseURL: URL) {
        self.client = client
        self.baseURL = baseURL
    }

    public func get() async throws -> Cart {
        let request = NetRequest.Builder()
            .url(
                baseURL
                    .appendingPathComponent("ecommerce")
                    .appendingPathComponent("cart")
                    .absoluteString
            )
            .method(.get)
            .shouldCache(false)
            .build()
        let response: FreeAPIEnvelope<CartDataDTO> = try await client.request(request)
        return response.data.toDomain()
    }

    public func addItem(productId: String) async throws -> Cart {
        let request = NetRequest.Builder()
            .url(
                baseURL
                    .appendingPathComponent("ecommerce")
                    .appendingPathComponent("cart")
                    .appendingPathComponent("item")
                    .appendingPathComponent(productId)
                    .absoluteString
            )
            .method(.post)
            .shouldCache(false)
            .build()
        let response: FreeAPIEnvelope<CartDataDTO> = try await client.request(request)
        return response.data.toDomain()
    }
}
