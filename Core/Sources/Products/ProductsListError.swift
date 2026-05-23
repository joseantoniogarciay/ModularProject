import Foundation

public enum ProductsListError: Error, Sendable {
    case noConnection
    case unknown(any Error)
}
