import Foundation

struct RefreshRequestBody: Encodable, Sendable {
    let refreshToken: String
}

struct RefreshDataDTO: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
}
