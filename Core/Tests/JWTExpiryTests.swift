import Foundation
import XCTest
@testable import Core

final class JWTExpiryTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a minimal, syntactically valid JWT with the given claims in the payload.
    private func makeJWT(payloadJSON: String) -> String {
        // A real (but signature-less) JWT: header.payload.signature
        let header = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let payloadBase64 = Data(payloadJSON.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "\(header).\(payloadBase64).fakesig"
    }

    private func makeJWT(exp: Double, extra: [String: String] = [:]) -> String {
        let fields = extra.map { ",\"\($0.key)\":\"\($0.value)\"" }.joined()
        return makeJWT(payloadJSON: "{\"exp\":\(exp)\(fields)}")
    }

    // MARK: - Happy path

    func testValidToken_returnsCorrectExpirationDate() {
        let exp: Double = 1_700_000_000
        let token = makeJWT(exp: exp)

        let date = JWTExpiry.expirationDate(of: token)

        XCTAssertEqual(date, Date(timeIntervalSince1970: exp))
    }

    // MARK: - Malformed structure

    func testEmptyString_returnsNil() {
        XCTAssertNil(JWTExpiry.expirationDate(of: ""))
    }

    func testSingleSegment_returnsNil() {
        XCTAssertNil(JWTExpiry.expirationDate(of: "onlyone"))
    }

    func testTwoSegmentsNoSignature_stillParsesPayload() {
        // split(separator:) produces 2 parts; guard segments.count >= 2 should pass
        let exp: Double = 1_700_000_000
        let payloadBase64 = Data("{\"exp\":\(exp)}".utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let token = "header.\(payloadBase64)"

        XCTAssertEqual(JWTExpiry.expirationDate(of: token), Date(timeIntervalSince1970: exp))
    }

    // MARK: - Bad payload

    func testInvalidBase64Payload_returnsNil() {
        // "!!!!" cannot be decoded as base64
        XCTAssertNil(JWTExpiry.expirationDate(of: "header.!!!!.sig"))
    }

    func testValidBase64ButNotJSON_returnsNil() {
        // "aGVsbG8=" decodes to "hello" — valid base64, not JSON
        let notJSON = Data("hello".utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        XCTAssertNil(JWTExpiry.expirationDate(of: "header.\(notJSON).sig"))
    }

    func testMissingExpClaim_returnsNil() {
        let token = makeJWT(payloadJSON: "{\"sub\":\"user123\"}")
        XCTAssertNil(JWTExpiry.expirationDate(of: token))
    }

    func testExpAsStringNotDouble_returnsNil() {
        let token = makeJWT(payloadJSON: "{\"exp\":\"notanumber\"}")
        XCTAssertNil(JWTExpiry.expirationDate(of: token))
    }

    // MARK: - Base64 URL padding variants
    //
    // The payload JSON length determines how many '=' padding chars base64 needs
    // (0, 1, or 2). The implementation strips them and re-adds them before decoding.
    // These four cases exercise remainder values 0, 1, 2, and 3 (via different JSON lengths).

    func testBase64PaddingVariants_allReturnCorrectDate() {
        let exp: Double = 1_700_000_000

        for suffix in ["", "a", "ab", "abc"] {
            let token = makeJWT(exp: exp, extra: ["x": suffix])
            let date = JWTExpiry.expirationDate(of: token)
            XCTAssertEqual(
                date,
                Date(timeIntervalSince1970: exp),
                "Failed for suffix '\(suffix)'"
            )
        }
    }
}
