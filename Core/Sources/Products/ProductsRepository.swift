import Foundation

public protocol ProductsRepository: Sendable {
    func list() async throws -> [Product]
}
