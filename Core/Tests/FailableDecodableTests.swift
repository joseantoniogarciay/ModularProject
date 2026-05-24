import Foundation
import XCTest
@testable import Core

// MARK: - Fixture

private struct Item: Decodable, Equatable {
    let id: Int
}

// MARK: - FailableDecodable

final class FailableDecodableTests: XCTestCase {

    func testValidJSON_decodesBase() throws {
        let json = Data(#"{"id":1}"#.utf8)
        let result = try JSONDecoder().decode(FailableDecodable<Item>.self, from: json)
        XCTAssertEqual(result.base, Item(id: 1))
    }

    func testInvalidJSON_baseIsNilAndDoesNotThrow() throws {
        // "id" should be Int but we give a String — the inner decode fails silently.
        let json = Data(#"{"id":"notanint"}"#.utf8)
        let result = try JSONDecoder().decode(FailableDecodable<Item>.self, from: json)
        XCTAssertNil(result.base)
    }
}

// MARK: - FailableDecodableArray

final class FailableDecodableArrayTests: XCTestCase {

    func testAllValidElements_returnsAll() throws {
        let json = Data(#"[{"id":1},{"id":2},{"id":3}]"#.utf8)
        let result = try JSONDecoder().decode(FailableDecodableArray<Item>.self, from: json)
        XCTAssertEqual(result.elements, [Item(id: 1), Item(id: 2), Item(id: 3)])
    }

    func testMixedElements_skipsInvalidOnesPreservesOrder() throws {
        // Position 1 (id:"bad") is invalid; positions 0 and 2 are valid.
        let json = Data(#"[{"id":1},{"id":"bad"},{"id":3}]"#.utf8)
        let result = try JSONDecoder().decode(FailableDecodableArray<Item>.self, from: json)
        XCTAssertEqual(result.elements, [Item(id: 1), Item(id: 3)])
    }

    func testAllInvalidElements_returnsEmptyArray() throws {
        let json = Data(#"[{"id":"bad"},{"id":"also-bad"}]"#.utf8)
        let result = try JSONDecoder().decode(FailableDecodableArray<Item>.self, from: json)
        XCTAssertTrue(result.elements.isEmpty)
    }

    func testEmptyArray_returnsEmptyArray() throws {
        let json = Data("[]".utf8)
        let result = try JSONDecoder().decode(FailableDecodableArray<Item>.self, from: json)
        XCTAssertTrue(result.elements.isEmpty)
    }

    func testSingleValidElement_returnsThatElement() throws {
        let json = Data(#"[{"id":42}]"#.utf8)
        let result = try JSONDecoder().decode(FailableDecodableArray<Item>.self, from: json)
        XCTAssertEqual(result.elements, [Item(id: 42)])
    }
}
