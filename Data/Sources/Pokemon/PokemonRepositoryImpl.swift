import Core
import Foundation

public struct PokemonRepositoryImpl: PokemonRepository {
    private let client: any NetClient
    private let baseURL: URL

    public init(
        client: any NetClient,
        baseURL: URL = URL(string: "https://pokeapi.co/api/v2")!
    ) {
        self.client = client
        self.baseURL = baseURL
    }

    public func list(offset: Int, limit: Int) async throws -> [Pokemon] {
        let request = NetRequest.Builder()
            .url(baseURL.appendingPathComponent("pokemon").absoluteString)
            .method(.get)
            .queryItem(name: "offset", value: String(offset))
            .queryItem(name: "limit", value: String(limit))
            .build()
        let response: PokemonListDTO = try await client.request(request)
        return response.results.compactMap { $0.toDomain() }
    }

    public func detail(id: Int) async throws -> PokemonDetail {
        let request = NetRequest.Builder()
            .url(baseURL.appendingPathComponent("pokemon/\(id)").absoluteString)
            .method(.get)
            .build()
        let response: PokemonDetailDTO = try await client.request(request)
        return response.toDomain()
    }
}
