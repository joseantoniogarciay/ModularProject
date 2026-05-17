import Foundation

public protocol CartRepository: Sendable {
    func get() async throws(CartFetchError) -> Cart
    func addItem(productId: String) async throws(CartAddItemError) -> Cart
}
