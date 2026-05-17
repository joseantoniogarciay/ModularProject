import Foundation

public enum RefreshError: Error, Sendable {
    case noConnection
    case refreshTokenInvalid
    case unknown(any Error)
}
