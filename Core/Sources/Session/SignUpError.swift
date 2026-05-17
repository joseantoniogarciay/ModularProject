import Foundation

public enum SignUpError: Error, Sendable {
    case noConnection
    case usernameOrEmailTaken
    case autoLoginFailed(any Error)
    case unknown(any Error)
}
