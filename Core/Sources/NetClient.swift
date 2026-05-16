import Foundation

public protocol NetClient: Sendable {
    func request(_ request: NetRequest) async throws -> NetworkResponse
    func request<T: Decodable & Sendable>(_ request: NetRequest) async throws -> T
    func upload(
        _ request: NetRequest,
        archives: [FormData],
        jsonKey: String,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> NetworkResponse
    func cancelAllTasks()
}
