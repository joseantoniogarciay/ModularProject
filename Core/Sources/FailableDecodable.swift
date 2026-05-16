import Foundation

public struct FailableDecodable<Base: Decodable>: Decodable {
    public let base: Base?

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.base = try? container.decode(Base.self)
    }
}

extension FailableDecodable: Sendable where Base: Sendable {}
