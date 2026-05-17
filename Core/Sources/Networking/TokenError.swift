import Foundation

public enum TokenError: Error, Sendable {
    case notAuthenticated
    case refreshFailed
}
