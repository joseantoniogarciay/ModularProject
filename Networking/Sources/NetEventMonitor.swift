import Alamofire
import Foundation
import OSLog

final class NetEventMonitor: EventMonitor, Sendable {
    let queue = DispatchQueue(label: "net.alamofire.logger")
    private let logger = Logger(subsystem: "com.modular.app.networking", category: "net")
    private let sessionHeaders: HTTPHeaders?
    private let additionalHeaders: [String: String]?

    init(sessionHeaders: HTTPHeaders? = nil, additionalHeaders: [String: String]? = nil) {
        self.sessionHeaders = sessionHeaders
        self.additionalHeaders = additionalHeaders
    }

    func request(_ request: DataRequest, didParseResponse response: DataResponse<Data?, AFError>) {
        log(response.result, debugDescription: response.debugDescription)
    }

    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        log(response.result, debugDescription: response.debugDescription)
    }

    private func log<Value>(_ result: Result<Value, AFError>, debugDescription: String) {
        switch result {
        case .success:
            if let sessionHeaders {
                logger.info("\(self.description(for: sessionHeaders), privacy: .public)")
            }
            if let additionalHeaders {
                logger.info("\(self.description(for: additionalHeaders), privacy: .public)")
            }
            logger.info("\(debugDescription, privacy: .public)")
        case .failure:
            if let sessionHeaders {
                logger.error("\(self.description(for: sessionHeaders), privacy: .public)")
            }
            logger.error("\(debugDescription, privacy: .public)")
        }
    }

    private func description(for headers: HTTPHeaders) -> String {
        guard !headers.isEmpty else { return "[Session Headers]: None" }
        return "[Session Headers]:\n    \(headers.sorted())"
    }

    private func description(for additionalHeaders: [String: String]?) -> String {
        guard let headers = additionalHeaders, !headers.isEmpty else {
            return "[Session Additional Headers]: None"
        }
        let body = headers
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n    ")
        return "[Session Additional Headers]:\n    \(body)"
    }
}
