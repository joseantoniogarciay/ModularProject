import Foundation

struct LoginRequestBody: Encodable, Sendable {
    let email: String?
    let username: String?
    let password: String
}

struct LoginDataDTO: Decodable, Sendable {
    let user: UserDTO
    let accessToken: String
    let refreshToken: String
}

struct RefreshRequestBody: Encodable, Sendable {
    let refreshToken: String
}

struct RefreshDataDTO: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
}
