import Foundation

public enum ProductsListError: Error, Sendable {
    case noConnection
    case notAuthenticated
    case unknown(any Error)
}
