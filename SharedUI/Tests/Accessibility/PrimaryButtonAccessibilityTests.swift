import UIKit
import XCTest
@testable import SharedUI

// Unit tests for PrimaryButton accessibility contracts.
// These verify properties that are statically checkable and worth anchoring as regressions:
//   - Hit region ≥ 44pt (explicit 52pt height constraint is a design contract)
//   - Loading state keeps the button in the accessibility tree
//
// NOT included here (tested by performAccessibilityAudit in AppUITests instead):
//   - Color contrast, VoiceOver order, label completeness across the whole screen

final class PrimaryButtonAccessibilityTests: XCTestCase {

    // MARK: - Hit region

    @MainActor
    func testHeightMeetsMinimumHitRegion() {
        // PrimaryButton has an explicit 52pt height constraint — well above the 44pt minimum.
        let (window, vc, button) = makeScene(title: "Continue")
        vc.view.layoutIfNeeded()
        _ = window

        XCTAssertGreaterThanOrEqual(
            button.frame.height, 44,
            "PrimaryButton must be at least 44pt tall for a comfortable tap target"
        )
    }

    @MainActor
    func testHeightMeetsMinimumHitRegionAtAX5() {
        // The headline font scales at AX5. The explicit height constraint (52pt) must
        // hold — UIButton.Configuration clips content rather than shrinking the button.
        let (window, vc, button) = makeScene(title: "Continue")
        _ = window
        vc.view.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        vc.view.layoutIfNeeded()

        XCTAssertGreaterThanOrEqual(
            button.frame.height, 44,
            "PrimaryButton must remain at least 44pt tall at AX5"
        )
    }

    // MARK: - Loading state

    @MainActor
    func testLoadingStateDisablesInteractionButKeepsAccessibilityElement() {
        // When isLoading = true, UIButton.Configuration + showsActivityIndicator was observed
        // to clear isAccessibilityElement in iOS 18. The fix is an explicit reassignment.
        // This test pins that fix against future regressions.
        let (window, vc, button) = makeScene(title: "Continue", isLoading: true)
        vc.view.layoutIfNeeded()
        _ = window

        XCTAssertFalse(
            button.isUserInteractionEnabled,
            "isLoading = true must disable user interaction"
        )
        XCTAssertTrue(
            button.isAccessibilityElement,
            "Loading button must stay in the accessibility tree so VoiceOver announces it"
        )
    }

    // MARK: - Scene factory

    @MainActor
    private func makeScene(
        title: String,
        isLoading: Bool = false
    ) -> (window: UIWindow, vc: UIViewController, button: PrimaryButton) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.makeKeyAndVisible()

        let vc = UIViewController()
        vc.view.backgroundColor = SharedUIAsset.background.color
        window.rootViewController = vc

        let button = PrimaryButton()
        button.setTitle(title, for: .normal)
        button.isLoading = isLoading
        button.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
            button.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 24),
            button.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -24),
        ])

        return (window, vc, button)
    }
}
