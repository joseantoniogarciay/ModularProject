import Foundation

public enum PokemonListError: Error, Sendable {
    case noConnection
    case unknown(any Error)
}
