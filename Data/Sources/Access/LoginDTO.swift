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
