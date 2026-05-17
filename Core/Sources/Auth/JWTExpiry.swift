import Foundation

public enum JWTExpiry {
    public static func expirationDate(of token: String) -> Date? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        guard let payload = decodeBase64URL(String(segments[1])) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else { return nil }
        guard let exp = json["exp"] as? Double else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}
