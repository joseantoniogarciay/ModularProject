import Foundation

public protocol PokemonRepository: Sendable {
    func list(offset: Int, limit: Int) async throws(PokemonListError) -> [Pokemon]
    func detail(id: Int) async throws(PokemonDetailError) -> PokemonDetail
}
