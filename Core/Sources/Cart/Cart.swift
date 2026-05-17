import Foundation

public struct Cart: Sendable {
    public let items: [CartItem]
    public let total: Double

    public init(items: [CartItem], total: Double) {
        self.items = items
        self.total = total
    }
}

public struct CartItem: Sendable {
    public let id: String
    public let productId: String
    public let productName: String
    public let unitPrice: Double
    public let quantity: Int

    public init(id: String, productId: String, productName: String, unitPrice: Double, quantity: Int) {
        self.id = id
        self.productId = productId
        self.productName = productName
        self.unitPrice = unitPrice
        self.quantity = quantity
    }
}
