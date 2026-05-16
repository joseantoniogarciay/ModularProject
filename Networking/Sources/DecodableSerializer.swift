import Alamofire
import Foundation

struct DecodableSerializer<T: Decodable & Sendable>: ResponseSerializer {
    typealias SerializedObject = T

    let decoder: JSONDecoder

    init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    func serialize(
        request: URLRequest?,
        response: HTTPURLResponse?,
        data: Data?,
        error: (any Error)?
    ) throws -> T {
        if let error {
            throw error
        }
        guard let data else {
            throw AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AFError.responseSerializationFailed(reason: .decodingFailed(error: error))
        }
    }
}
