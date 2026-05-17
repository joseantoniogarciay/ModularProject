import Foundation

public enum LoginError: Error, Sendable {
    case noConnection
    case invalidCredentials
    case unknown(any Error)
}
