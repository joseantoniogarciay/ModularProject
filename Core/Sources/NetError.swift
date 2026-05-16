import Foundation

public enum NetError: Error, Sendable {
    case noConnection
    case cancelled
    case invalidURL
    case http(statusCode: Int, data: Data?, headers: [String: String]?)
    case encoding(any Error)
    case decoding(any Error)
    case transport(any Error)
}
