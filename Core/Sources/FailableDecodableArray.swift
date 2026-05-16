import Foundation

public struct FailableDecodableArray<Element: Decodable>: Decodable {
    public let elements: [Element]

    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        if let count = container.count {
            elements.reserveCapacity(count)
        }
        while !container.isAtEnd {
            if let element = try container.decode(FailableDecodable<Element>.self).base {
                elements.append(element)
            }
        }
        self.elements = elements
    }
}

extension FailableDecodableArray: Sendable where Element: Sendable {}
