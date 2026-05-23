import Foundation

public enum CartFetchError: Error, Sendable {
    case noConnection
    case unknown(any Error)
}
