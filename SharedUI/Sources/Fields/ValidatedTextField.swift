import UIKit

public typealias TextFieldValidator = (String) -> String?

@MainActor
public final class ValidatedTextField: UIView {
    public let textField = UITextField()
    private let line = UIView()
    private let errorLabel = UILabel()
    private let innerStack: UIStackView

    private let validators: [TextFieldValidator]

    public var text: String? { textField.text }

    public init(placeholder: String, validators: [TextFieldValidator] = []) {
        self.validators = validators
        self.innerStack = UIStackView()
        super.init(frame: .zero)
        setup(placeholder: placeholder)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func setup(placeholder: String) {
        textField.placeholder = placeholder
        textField.borderStyle = .none
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true

        line.backgroundColor = SharedUIAsset.secondaryText.color.withAlphaComponent(0.3)

        errorLabel.font = .preferredFont(forTextStyle: .caption1)
        errorLabel.adjustsFontForContentSizeCategory = true
        errorLabel.textColor = SharedUIAsset.bannerErrorForeground.color
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        let fieldContainer = UIView()
        textField.translatesAutoresizingMaskIntoConstraints = false
        line.translatesAutoresizingMaskIntoConstraints = false
        fieldContainer.addSubview(textField)
        fieldContainer.addSubview(line)

        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: fieldContainer.topAnchor),
            textField.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor),
            textField.heightAnchor.constraint(equalToConstant: 44),

            line.topAnchor.constraint(equalTo: textField.bottomAnchor),
            line.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: 1),
            line.bottomAnchor.constraint(equalTo: fieldContainer.bottomAnchor),
        ])

        innerStack.axis = .vertical
        innerStack.spacing = 4
        innerStack.alignment = .fill
        innerStack.addArrangedSubview(fieldContainer)
        innerStack.addArrangedSubview(errorLabel)

        addSubview(innerStack)
        innerStack.pinEdges(to: self)
    }

    @discardableResult
    public func validate() -> Bool {
        let value = textField.text ?? ""
        for validator in validators {
            if let message = validator(value) {
                setError(message)
                return false
            }
        }
        clearError()
        return true
    }

    private func setError(_ message: String) {
        errorLabel.text = message
        guard errorLabel.isHidden else { return }
        UIView.animate(withDuration: 0.2) { [weak self] in
            guard let self else { return }
            self.errorLabel.isHidden = false
            self.superview?.layoutIfNeeded()
        }
    }

    private func clearError() {
        guard !errorLabel.isHidden else { return }
        UIView.animate(withDuration: 0.2) { [weak self] in
            guard let self else { return }
            self.errorLabel.isHidden = true
            self.superview?.layoutIfNeeded()
        }
    }
}
