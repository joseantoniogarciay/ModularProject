import Foundation

struct RegisterRequestBody: Encodable, Sendable {
    let email: String
    let username: String
    let password: String
    let role: String
}

struct RegisterDataDTO: Decodable, Sendable {
    let user: UserDTO
}
