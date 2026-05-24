import UIKit
import XCTest
@testable import SharedUI

// Unit tests for RetryView accessibility contracts.
// These verify properties that are statically checkable and worth anchoring as regressions:
//   - Dynamic Type: adjustsFontForContentSizeCategory + numberOfLines = 0 on body labels
//
// NOT included here (tested by performAccessibilityAudit in AppUITests instead):
//   - Color contrast, VoiceOver order, label completeness across the whole screen

final class RetryViewAccessibilityTests: XCTestCase {

    // MARK: - Dynamic Type

    @MainActor
    func testLabelsUseDynamicType() {
        let (window, vc, view) = makeScene(message: "Something went wrong.", retryTitle: "Try again")
        vc.view.layoutIfNeeded()
        _ = window // keep alive

        // Only check standalone UILabels — button title labels are intentionally single-line.
        let labels = view.findSubviews(ofType: UILabel.self)
            .filter { !($0.text?.isEmpty ?? true) && !$0.isInsideButton }

        XCTAssertFalse(labels.isEmpty, "RetryView must render at least one standalone label")

        for label in labels {
            XCTAssertTrue(
                label.adjustsFontForContentSizeCategory,
                "'\(label.text ?? "")' must set adjustsFontForContentSizeCategory = true"
            )
            XCTAssertEqual(
                label.numberOfLines, 0,
                "'\(label.text ?? "")' must use numberOfLines = 0 to avoid truncation at AX5"
            )
        }
    }

    // MARK: - Scene factory

    @MainActor
    private func makeScene(
        message: String,
        retryTitle: String
    ) -> (window: UIWindow, vc: UIViewController, view: RetryView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.makeKeyAndVisible()

        let vc = UIViewController()
        vc.view.backgroundColor = SharedUIAsset.background.color
        window.rootViewController = vc

        let retryView = RetryView()
        retryView.configure(message: message, retryTitle: retryTitle)
        retryView.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(retryView)

        NSLayoutConstraint.activate([
            retryView.topAnchor.constraint(equalTo: vc.view.topAnchor),
            retryView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
            retryView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            retryView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
        ])

        return (window, vc, retryView)
    }
}
