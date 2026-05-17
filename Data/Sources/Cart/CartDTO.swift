import Core
import Foundation

struct CartDataDTO: Decodable, Sendable {
    let items: [CartItemDTO]?
    let cartTotal: Double?
}

struct CartItemDTO: Decodable, Sendable {
    let id: String
    let product: ProductDTO?
    let quantity: Int

    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case product
        case quantity
    }
}

struct ProductDTO: Decodable, Sendable {
    let id: String
    let name: String?
    let price: Double?

    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case price
    }
}

extension CartDataDTO {
    func toDomain() -> Cart {
        Cart(
            items: (items ?? []).compactMap { $0.toDomain() },
            total: cartTotal ?? 0
        )
    }
}

extension CartItemDTO {
    func toDomain() -> CartItem? {
        guard let product else { return nil }
        return CartItem(
            id: id,
            productId: product.id,
            productName: product.name ?? "",
            unitPrice: product.price ?? 0,
            quantity: quantity
        )
    }
}
