import Core
import Foundation

struct UserDTO: Decodable, Sendable {
    let id: String
    let username: String
    let email: String
    let role: String?
    let avatar: AvatarDTO?

    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case username
        case email
        case role
        case avatar
    }
}

struct AvatarDTO: Decodable, Sendable {
    let url: String?
}

extension UserDTO {
    func toDomain() -> User {
        User(
            id: id,
            username: username,
            email: email,
            role: role,
            avatarURL: avatar?.url.flatMap(URL.init(string:))
        )
    }
}
