import Foundation
import XCTest
@testable import SharedUI

final class TextFieldValidatorsTests: XCTestCase {

    // Constant reused across all cases — the actual message content is not under test.
    private let message = "Error"

    // MARK: - notEmpty

    func testNotEmpty_emptyString_returnsMessage() {
        let validate = TextFieldValidators.notEmpty(message)
        XCTAssertEqual(validate(""), message)
    }

    func testNotEmpty_whitespaceOnly_returnsMessage() {
        let validate = TextFieldValidators.notEmpty(message)
        XCTAssertEqual(validate("   "), message)
    }

    func testNotEmpty_tabsAndNewlines_returnsNil() {
        // notEmpty trims with .whitespaces, which does NOT include tabs or newlines.
        // A field containing only "\t\n" is considered non-empty by this validator.
        // Single-line UITextField inputs cannot produce these characters in practice,
        // so the current behaviour is intentional.
        let validate = TextFieldValidators.notEmpty(message)
        XCTAssertNil(validate("\t\n"))
    }

    func testNotEmpty_nonEmptyString_returnsNil() {
        let validate = TextFieldValidators.notEmpty(message)
        XCTAssertNil(validate("hello"))
    }

    func testNotEmpty_stringWithSurroundingSpaces_returnsNil() {
        // Trimming should only strip the edges, not discard a non-empty interior.
        let validate = TextFieldValidators.notEmpty(message)
        XCTAssertNil(validate("  hi  "))
    }

    // MARK: - minLength

    func testMinLength_belowMinimum_returnsMessage() {
        let validate = TextFieldValidators.minLength(5, message: message)
        XCTAssertEqual(validate("hi"), message)
    }

    func testMinLength_oneCharacterBelow_returnsMessage() {
        let validate = TextFieldValidators.minLength(5, message: message)
        XCTAssertEqual(validate("hell"), message)  // 4 < 5
    }

    func testMinLength_exactMinimum_returnsNil() {
        let validate = TextFieldValidators.minLength(5, message: message)
        XCTAssertNil(validate("hello"))  // 5 is NOT < 5
    }

    func testMinLength_aboveMinimum_returnsNil() {
        let validate = TextFieldValidators.minLength(5, message: message)
        XCTAssertNil(validate("hello world"))
    }

    func testMinLength_emptyStringWithMinOne_returnsMessage() {
        let validate = TextFieldValidators.minLength(1, message: message)
        XCTAssertEqual(validate(""), message)
    }

    func testMinLength_minZero_alwaysReturnsNil() {
        // count < 0 is never true.
        let validate = TextFieldValidators.minLength(0, message: message)
        XCTAssertNil(validate(""))
        XCTAssertNil(validate("anything"))
    }

    // MARK: - email

    func testEmail_typicalAddress_returnsNil() {
        let validate = TextFieldValidators.email(message)
        XCTAssertNil(validate("user@example.com"))
    }

    func testEmail_subdomain_returnsNil() {
        let validate = TextFieldValidators.email(message)
        XCTAssertNil(validate("user@mail.example.co.uk"))
    }

    func testEmail_allUppercase_returnsNil() {
        // Regex uses [c] (case-insensitive) flag.
        let validate = TextFieldValidators.email(message)
        XCTAssertNil(validate("USER@EXAMPLE.COM"))
    }

    func testEmail_plusAddressing_returnsNil() {
        let validate = TextFieldValidators.email(message)
        XCTAssertNil(validate("user+tag@example.com"))
    }

    func testEmail_emptyString_returnsMessage() {
        let validate = TextFieldValidators.email(message)
        XCTAssertEqual(validate(""), message)
    }

    func testEmail_missingAtSign_returnsMessage() {
        let validate = TextFieldValidators.email(message)
        XCTAssertEqual(validate("userexample.com"), message)
    }

    func testEmail_missingLocalPart_returnsMessage() {
        let validate = TextFieldValidators.email(message)
        XCTAssertEqual(validate("@example.com"), message)
    }

    func testEmail_missingDomain_returnsMessage() {
        let validate = TextFieldValidators.email(message)
        XCTAssertEqual(validate("user@"), message)
    }

    func testEmail_missingTLD_returnsMessage() {
        let validate = TextFieldValidators.email(message)
        XCTAssertEqual(validate("user@example"), message)
    }

    func testEmail_singleCharTLD_returnsMessage() {
        // TLD must be {2,} characters per the regex.
        let validate = TextFieldValidators.email(message)
        XCTAssertEqual(validate("user@example.c"), message)
    }
}
