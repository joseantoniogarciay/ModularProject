import Foundation

public enum CartAddItemError: Error, Sendable {
    case noConnection
    case unknown(any Error)
}
