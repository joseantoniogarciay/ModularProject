import Foundation

public enum RegisterError: Error, Sendable {
    case noConnection
    case usernameOrEmailTaken
    case unknown(any Error)
}
