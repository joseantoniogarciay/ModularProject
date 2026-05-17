import Foundation

public protocol TokenStore: Sendable {
    func load() async -> AuthTokens?
    func save(_ tokens: AuthTokens) async
    func clear() async
}
