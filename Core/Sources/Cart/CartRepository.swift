import Foundation

public protocol CartRepository: Sendable {
    func get() async throws -> Cart
    func addItem(productId: String) async throws -> Cart
}
