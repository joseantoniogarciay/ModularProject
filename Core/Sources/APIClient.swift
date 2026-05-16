import Foundation

public protocol APIClient: Sendable {
    func get<Response: Decodable & Sendable>(_ path: String) async throws -> Response
}

public enum APIError: Error, Sendable {
    case invalidResponse
    case decoding(any Error)
    case transport(any Error)
}
