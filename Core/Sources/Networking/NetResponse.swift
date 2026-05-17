import Foundation

public struct NetResponse: Sendable {
    public let statusCode: Int
    public let data: Data?
    public let headers: [String: String]?

    public init(statusCode: Int, data: Data?, headers: [String: String]?) {
        self.statusCode = statusCode
        self.data = data
        self.headers = headers
    }
}
