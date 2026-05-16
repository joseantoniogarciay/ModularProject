import Alamofire
import Core
import Foundation

public struct AlamofireNetClient: NetClient {
    private let session: Session

    public init(
        userAgent: String,
        requestTimeout: TimeInterval = 20
    ) {
        let configuration = Self.makeConfiguration(
            userAgent: userAgent,
            requestTimeout: requestTimeout
        )
        let eventMonitors = Self.makeEventMonitors(
            additionalHeaders: configuration.httpAdditionalHeaders
        )
        self.session = Session(
            configuration: configuration,
            delegate: SessionDelegate(),
            rootQueue: DispatchQueue(label: "net.alamofire.rootQueue"),
            requestQueue: DispatchQueue(label: "net.alamofire.requestQueue"),
            serializationQueue: DispatchQueue(label: "net.alamofire.serializationQueue"),
            eventMonitors: eventMonitors
        )
    }

    public func request(_ request: NetRequest) async throws -> NetworkResponse {
        let dataRequest = try makeDataRequest(request)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NetworkResponse, any Error>) in
                dataRequest.validate().response(queue: .global()) { dataResponse in
                    switch dataResponse.result {
                    case .success(let data):
                        continuation.resume(returning: NetworkResponse(
                            statusCode: dataResponse.response?.statusCode ?? -1,
                            data: data,
                            headers: dataResponse.request?.allHTTPHeaderFields
                        ))
                    case .failure(let error):
                        continuation.resume(throwing: Self.map(error, response: dataResponse))
                    }
                }
                dataRequest.resume()
            }
        } onCancel: {
            dataRequest.cancel()
        }
    }

    public func request<T: Decodable & Sendable>(_ request: NetRequest) async throws -> T {
        let dataRequest = try makeDataRequest(request)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, any Error>) in
                dataRequest
                    .validate()
                    .response(queue: .global(), responseSerializer: DecodableSerializer<T>()) { dataResponse in
                        switch dataResponse.result {
                        case .success(let value):
                            continuation.resume(returning: value)
                        case .failure(let error):
                            continuation.resume(throwing: Self.map(error, response: dataResponse))
                        }
                    }
                dataRequest.resume()
            }
        } onCancel: {
            dataRequest.cancel()
        }
    }

    public func upload(
        _ request: NetRequest,
        archives: [FormData],
        jsonKey: String,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> NetworkResponse {
        guard let url = URL(string: request.url) else {
            throw NetError.invalidURL
        }
        let urlRequest: URLRequest
        do {
            urlRequest = try URLRequest(
                url: url,
                method: Self.transform(request.method),
                headers: HTTPHeaders(request.headers)
            )
        } catch {
            throw NetError.encoding(error)
        }
        let jsonPart: Data?
        do {
            jsonPart = try Self.bodyAsJSONData(request.body)
        } catch {
            throw NetError.encoding(error)
        }

        let uploadRequest = session.upload(multipartFormData: { form in
            for archive in archives {
                form.append(
                    archive.data,
                    withName: archive.apiName,
                    fileName: archive.fileName,
                    mimeType: archive.mimeType
                )
            }
            if let jsonPart {
                form.append(jsonPart, withName: jsonKey, mimeType: "application/json")
            }
        }, with: urlRequest)

        if let progress {
            uploadRequest.uploadProgress { progressValue in
                progress(progressValue.fractionCompleted)
            }
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NetworkResponse, any Error>) in
                uploadRequest.validate().response(queue: .global()) { dataResponse in
                    switch dataResponse.result {
                    case .success(let data):
                        continuation.resume(returning: NetworkResponse(
                            statusCode: dataResponse.response?.statusCode ?? -1,
                            data: data,
                            headers: dataResponse.request?.allHTTPHeaderFields
                        ))
                    case .failure(let error):
                        continuation.resume(throwing: Self.map(error, response: dataResponse))
                    }
                }
                uploadRequest.resume()
            }
        } onCancel: {
            uploadRequest.cancel()
        }
    }

    public func cancelAllTasks() {
        session.cancelAllRequests()
    }

    // MARK: - Private

    private func makeDataRequest(_ request: NetRequest) throws -> DataRequest {
        guard let baseURL = URL(string: request.url) else {
            throw NetError.invalidURL
        }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        if !request.queryItems.isEmpty {
            let existing = components?.queryItems ?? []
            components?.queryItems = existing + request.queryItems
        }
        guard let url = components?.url else { throw NetError.invalidURL }

        var urlRequest: URLRequest
        do {
            urlRequest = try URLRequest(
                url: url,
                method: Self.transform(request.method),
                headers: HTTPHeaders(request.headers)
            )
        } catch {
            throw NetError.encoding(error)
        }

        if let body = request.body {
            do {
                try Self.apply(body, to: &urlRequest)
            } catch {
                throw NetError.encoding(error)
            }
        }

        return session.request(urlRequest)
    }

    private static func apply(_ body: Body, to urlRequest: inout URLRequest) throws {
        switch body {
        case .json(let encodable):
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try encodeJSON(encodable)
        case .form(let params):
            urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = urlEncoded(params).data(using: .utf8)
        case .raw(let data, let mimeType):
            urlRequest.setValue(mimeType, forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = data
        }
    }

    private static func bodyAsJSONData(_ body: Body?) throws -> Data? {
        switch body {
        case .none:
            return nil
        case .json(let encodable):
            return try encodeJSON(encodable)
        case .form(let params):
            return urlEncoded(params).data(using: .utf8)
        case .raw(let data, _):
            return data
        }
    }

    private static func encodeJSON<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    private static func urlEncoded(_ params: [String: String]) -> String {
        params
            .sorted { $0.key < $1.key }
            .map { key, value in
                let allowed = CharacterSet.urlQueryAllowed
                let escapedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let escapedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(escapedKey)=\(escapedValue)"
            }
            .joined(separator: "&")
    }

    private static func transform(_ method: Core.HTTPMethod) -> Alamofire.HTTPMethod {
        Alamofire.HTTPMethod(rawValue: method.rawValue.uppercased())
    }

    private static func map<Success: Sendable>(_ error: AFError, response: AFDataResponse<Success>) -> any Error {
        if let urlError = error.underlyingError as? URLError {
            if urlError.code == .cancelled {
                return NetError.cancelled
            }
            if urlError.code == .notConnectedToInternet {
                return NetError.noConnection
            }
        }
        return NetError.http(
            statusCode: response.response?.statusCode ?? -1,
            data: response.data,
            headers: response.request?.allHTTPHeaderFields
        )
    }

    private static func makeConfiguration(
        userAgent: String,
        requestTimeout: TimeInterval
    ) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = [
            "User-Agent": userAgent,
            HTTPHeader.defaultAcceptEncoding.name: HTTPHeader.defaultAcceptEncoding.value,
            HTTPHeader.defaultAcceptLanguage.name: HTTPHeader.defaultAcceptLanguage.value,
            "Accept": "application/json",
        ]
        return configuration
    }

    private static func makeEventMonitors(additionalHeaders: [AnyHashable: Any]?) -> [any EventMonitor] {
        #if DEBUG
        let headerMap: [String: String]? = additionalHeaders?.reduce(into: [:]) { result, pair in
            guard let key = pair.key as? String else { return }
            result[key] = "\(pair.value)"
        }
        return [NetEventMonitor(additionalHeaders: headerMap)]
        #else
        return []
        #endif
    }
}
