import Core
import Foundation

public struct ProductsRepositoryImpl: ProductsRepository {
    private let client: any NetClient
    private let baseURL: URL

    public init(client: any NetClient, baseURL: URL) {
        self.client = client
        self.baseURL = baseURL
    }

    public func list() async throws(ProductsListError) -> [Product] {
        let request = NetRequest.Builder()
            .url(
                baseURL
                    .appendingPathComponent("ecommerce")
                    .appendingPathComponent("products")
                    .absoluteString
            )
            .method(.get)
            .shouldCache(false)
            .build()
        do {
            let response: FreeAPIEnvelope<ProductListDataDTO> = try await client.request(request)
            return response.data.products.map { $0.toDomain() }
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
