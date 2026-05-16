import Alamofire
import Core
import Foundation

final class NetEventMonitor: EventMonitor, Sendable {
    let queue = DispatchQueue(label: "net.alamofire.logger")
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
        let format: LogFormat
        let includeAdditionalHeaders: Bool
        switch result {
        case .success:
            format = .info
            includeAdditionalHeaders = true
        case .failure:
            format = .error
            includeAdditionalHeaders = false
        }

        if let sessionHeaders {
            logMessage(description(for: sessionHeaders), category: .net, format: format)
        }
        if includeAdditionalHeaders, let additionalHeaders {
            logMessage(description(for: additionalHeaders), category: .net, format: format)
        }
        logMessage(debugDescription, category: .net, format: format)
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
