import Foundation

public enum AuthError: Error, Sendable {
    case notAuthenticated
    case invalidCredentials
    case usernameOrEmailTaken
    case refreshFailed
    case underlying(any Error)
}
