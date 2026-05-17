import Foundation

public enum CartAddItemError: Error, Sendable {
    case noConnection
    case notAuthenticated
    case unknown(any Error)
}
