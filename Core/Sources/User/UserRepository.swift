import Foundation

public protocol UserRepository: Sendable {
    func currentUser() async throws(CurrentUserError) -> User
}
