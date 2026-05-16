import Foundation

public struct FormData: Sendable {
    public let apiName: String
    public let fileName: String
    public let mimeType: String
    public let data: Data

    public init(apiName: String, fileName: String, mimeType: String, data: Data) {
        self.apiName = apiName
        self.fileName = fileName
        self.mimeType = mimeType
        self.data = data
    }
}
