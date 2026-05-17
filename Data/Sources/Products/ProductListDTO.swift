import Core
import Foundation

struct ProductListDataDTO: Decodable, Sendable {
    let products: [ProductListItemDTO]
}

struct ProductListItemDTO: Decodable, Sendable {
    let id: String
    let name: String

    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
    }
}

extension ProductListItemDTO {
    func toDomain() -> Product {
        Product(id: id, name: name)
    }
}
