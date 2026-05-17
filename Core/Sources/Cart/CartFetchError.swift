import Foundation

public enum CartFetchError: Error, Sendable {
    case noConnection
    case notAuthenticated
    case unknown(any Error)
}
