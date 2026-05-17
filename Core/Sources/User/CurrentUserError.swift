import Foundation

public enum CurrentUserError: Error, Sendable {
    case noConnection
    case notAuthenticated
    case unknown(any Error)
}
