import UIKit
import XCTest
@testable import novawallet

final class LegalConsentViewTests: XCTestCase {
    // MARK: - Accessibility

    func testCheckboxIsAnnouncedWithTheAgreementSentence() {
        let agreement = makeAgreement()
        let view = makeLayoutedView(with: agreement)

        XCTAssertTrue(view.checkboxControl.isAccessibilityElement)
        XCTAssertEqual(view.checkboxControl.accessibilityLabel, agreement.string)
        XCTAssertTrue(view.checkboxControl.accessibilityTraits.contains(.button))
    }

    func testCheckboxAnnouncesTheTickState() {
        let view = makeLayoutedView(with: makeAgreement())

        XCTAssertFalse(view.checkboxControl.accessibilityTraits.contains(.selected))

        view.isChecked = true

        XCTAssertTrue(view.checkboxControl.accessibilityTraits.contains(.selected))

        view.isChecked = false

        XCTAssertFalse(view.checkboxControl.accessibilityTraits.contains(.selected))
    }

    // MARK: - Touch target

    func testCheckboxTouchTargetIsAtLeast44ptAndInsideBounds() {
        let view = makeLayoutedView(with: makeAgreement())

        let target = view.checkboxControl.frame

        XCTAssertGreaterThanOrEqual(target.width, Constants.minimumTouchTarget)
        XCTAssertGreaterThanOrEqual(target.height, Constants.minimumTouchTarget)
        XCTAssertTrue(view.bounds.contains(target))

        let bottomLeft = CGPoint(
            x: target.minX + Constants.probeInset,
            y: target.maxY - Constants.probeInset
        )

        XCTAssertTrue(view.hitTest(bottomLeft, with: nil) === view.checkboxControl)
    }

    func testCheckboxArtworkKeepsItsPlace() {
        let view = makeLayoutedView(with: makeAgreement())

        let artwork = view.checkboxImageView.convert(view.checkboxImageView.bounds, to: view)

        XCTAssertEqual(artwork, CGRect(origin: .zero, size: Constants.artworkSize))
        XCTAssertEqual(view.textView.frame.minX, artwork.maxX + Constants.spacing)
        XCTAssertEqual(view.textView.frame.minY, artwork.minY)
    }
}

// MARK: - Private

private extension LegalConsentViewTests {
    enum Constants {
        static let minimumTouchTarget: CGFloat = 44.0
        static let artworkSize = CGSize(width: 24.0, height: 24.0)
        static let spacing: CGFloat = 12.0
        static let probeInset: CGFloat = 2.0
        static let width: CGFloat = 335.0
    }

    func makeAgreement() -> NSAttributedString {
        LegalConsentTextFactory.createAgreementText(for: Locale(identifier: "en"))
    }

    func makeLayoutedView(with agreement: NSAttributedString) -> LegalConsentView {
        let view = LegalConsentView()
        view.bind(agreement: agreement)

        let size = view.systemLayoutSizeFitting(
            CGSize(width: Constants.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        view.frame = CGRect(origin: .zero, size: size)
        view.layoutIfNeeded()

        return view
    }
}
