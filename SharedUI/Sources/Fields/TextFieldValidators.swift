import Foundation

public enum TextFieldValidators {
    public static func notEmpty(_ message: String) -> TextFieldValidator {
        { $0.trimmingCharacters(in: .whitespaces).isEmpty ? message : nil }
    }

    public static func minLength(_ length: Int, message: String) -> TextFieldValidator {
        { $0.count < length ? message : nil }
    }

    public static func email(_ message: String) -> TextFieldValidator {
        { text in
            let pattern = #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#
            let predicate = NSPredicate(format: "SELF MATCHES[c] %@", pattern)
            return predicate.evaluate(with: text) ? nil : message
        }
    }
}
