import Foundation

public protocol GetPokemonDetailUseCase: Sendable {
    func execute(id: Int) async throws -> PokemonDetail
}
