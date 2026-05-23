import Core
import Foundation

public struct CartRepositoryImpl: CartRepository {
    private let client: any NetClient
    private let baseURL: URL

    public init(client: any NetClient, baseURL: URL) {
        self.client = client
        self.baseURL = baseURL
    }

    public func get() async throws(CartFetchError) -> Cart {
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
        do {
            let response: FreeAPIEnvelope<CartDataDTO> = try await client.request(request)
            return response.data.toDomain()
        } catch let error as NetError {
            if case .noConnection = error { throw .noConnection }
            throw .unknown(error)
        } catch {
            throw .unknown(error)
        }
    }

    public func addItem(productId: String) async throws(CartAddItemError) -> Cart {
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
        do {
            let response: FreeAPIEnvelope<CartDataDTO> = try await client.request(request)
            return response.data.toDomain()
        } catch let error as NetError {
            if case .noConnection = error { throw .noConnection }
            throw .unknown(error)
        } catch {
            throw .unknown(error)
        }
    }
}
