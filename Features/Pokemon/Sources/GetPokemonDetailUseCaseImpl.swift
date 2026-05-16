import Core
import Foundation

public struct GetPokemonDetailUseCaseImpl: GetPokemonDetailUseCase {
    private let repository: any PokemonRepository

    public init(repository: any PokemonRepository) {
        self.repository = repository
    }

    public func execute(id: Int) async throws -> PokemonDetail {
        try await repository.detail(id: id)
    }
}
