import Foundation

struct FreeAPIEnvelope<Payload: Decodable & Sendable>: Decodable, Sendable {
    let statusCode: Int?
    let data: Payload
    let message: String?
    let success: Bool?
}
