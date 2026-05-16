import Foundation

public struct PokemonPage: Sendable {
    public let items: [Pokemon]
    public let hasMore: Bool

    public init(items: [Pokemon], hasMore: Bool) {
        self.items = items
        self.hasMore = hasMore
    }
}

public protocol ListPokemonUseCase: Sendable {
    func loadNext() async throws -> PokemonPage
    func reset() async
}
