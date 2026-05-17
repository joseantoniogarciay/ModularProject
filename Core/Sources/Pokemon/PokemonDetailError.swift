import Foundation

public enum PokemonDetailError: Error, Sendable {
    case noConnection
    case unknown(any Error)
}
