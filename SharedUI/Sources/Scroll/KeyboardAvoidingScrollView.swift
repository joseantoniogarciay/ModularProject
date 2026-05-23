import UIKit

@MainActor
public final class KeyboardAvoidingScrollView: UIScrollView {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        keyboardDismissMode = .interactive
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillShow(_:)),
                name: UIResponder.keyboardWillShowNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillHide(_:)),
                name: UIResponder.keyboardWillHideNotification,
                object: nil
            )
        } else {
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        }
    }

    @objc private nonisolated func keyboardWillShow(_ notification: Notification) {
        let endFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval) ?? 0.25
        let curveRaw = (notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt) ?? 0
        MainActor.assumeIsolated { [weak self] in
            self?.applyKeyboard(endFrame: endFrame, duration: duration, curveRaw: curveRaw, visible: true)
        }
    }

    @objc private nonisolated func keyboardWillHide(_ notification: Notification) {
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval) ?? 0.25
        let curveRaw = (notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt) ?? 0
        MainActor.assumeIsolated { [weak self] in
            self?.applyKeyboard(endFrame: .zero, duration: duration, curveRaw: curveRaw, visible: false)
        }
    }

    private func applyKeyboard(endFrame: CGRect, duration: TimeInterval, curveRaw: UInt, visible: Bool) {
        let options = UIView.AnimationOptions(rawValue: curveRaw << 16)

        let overlap: CGFloat
        if visible, let window {
            let myBottom = convert(CGPoint(x: 0, y: bounds.maxY), to: window).y
            overlap = max(0, myBottom - endFrame.origin.y)
        } else {
            overlap = 0
        }

        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.contentInset.bottom = overlap
            self.verticalScrollIndicatorInsets.bottom = overlap
        }

        if visible {
            scrollToFirstResponder()
        }
    }

    private func scrollToFirstResponder() {
        guard let responder = firstResponder(in: self) else { return }
        let rect = responder.convert(responder.bounds, to: self)
        scrollRectToVisible(rect.insetBy(dx: 0, dy: -16), animated: true)
    }

    private func firstResponder(in view: UIView) -> UIView? {
        if view.isFirstResponder { return view }
        for sub in view.subviews {
            if let found = firstResponder(in: sub) { return found }
        }
        return nil
    }
}
