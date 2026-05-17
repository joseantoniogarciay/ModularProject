import Core
import Foundation

public struct PokemonRepositoryImpl: PokemonRepository {
    private let client: any NetClient
    private let baseURL: URL

    public init(client: any NetClient, baseURL: URL) {
        self.client = client
        self.baseURL = baseURL
    }

    public func list(offset: Int, limit: Int) async throws(PokemonListError) -> [Pokemon] {
        let request = NetRequest.Builder()
            .url(baseURL.appendingPathComponent("pokemon").absoluteString)
            .method(.get)
            .queryItem(name: "offset", value: String(offset))
            .queryItem(name: "limit", value: String(limit))
            .build()
        do {
            let response: PokemonListDTO = try await client.request(request)
            return response.results.compactMap { $0.toDomain() }
        } catch let error as NetError {
            if case .noConnection = error { throw .noConnection }
            throw .unknown(error)
        } catch {
            throw .unknown(error)
        }
    }

    public func detail(id: Int) async throws(PokemonDetailError) -> PokemonDetail {
        let request = NetRequest.Builder()
            .url(
                baseURL
                    .appendingPathComponent("pokemon")
                    .appendingPathComponent("\(id)")
                    .absoluteString
            )
            .method(.get)
            .build()
        do {
            let response: PokemonDetailDTO = try await client.request(request)
            return response.toDomain()
        } catch let error as NetError {
            if case .noConnection = error { throw .noConnection }
            throw .unknown(error)
        } catch {
            throw .unknown(error)
        }
    }
}
