import Core
import Foundation

public actor ListPokemonUseCaseImpl: ListPokemonUseCase {
    private let repository: any PokemonRepository
    private let pageSize: Int
    private var offset: Int = 0
    private var hasMore: Bool = true
    private var loading: Bool = false

    public init(repository: any PokemonRepository, pageSize: Int = 30) {
        self.repository = repository
        self.pageSize = pageSize
    }

    public func loadNext() async throws -> PokemonPage {
        guard hasMore, !loading else {
            return PokemonPage(items: [], hasMore: hasMore)
        }
        loading = true
        defer { loading = false }
        let batch = try await repository.list(offset: offset, limit: pageSize)
        offset += batch.count
        if batch.count < pageSize {
            hasMore = false
        }
        return PokemonPage(items: batch, hasMore: hasMore)
    }

    public func reset() async {
        offset = 0
        hasMore = true
    }
}
