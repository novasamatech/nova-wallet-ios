import XCTest
@testable import novawallet

final class ModalCardPresentationFrameTests: XCTestCase {
    private let container = CGRect(x: 0, y: 0, width: 390, height: 844)

    func testFirstLevelCardFillsContainerBelowTopOffset() {
        // The container, not the presenting view, sizes the card: a presenting bottom sheet
        // owns only its pane and must still get a full-height card (NW-2379).
        let frame = ModalCardPresentationController.presentedViewFrame(
            containerBounds: container,
            safeAreaTop: 47,
            presentedByModalCard: false
        )

        XCTAssertEqual(frame, CGRect(x: 0, y: 59, width: 390, height: 785))
    }

    func testNestedCardKeepsContainerHeight() {
        let frame = ModalCardPresentationController.presentedViewFrame(
            containerBounds: CGRect(x: 0, y: 0, width: 390, height: 832),
            safeAreaTop: 0,
            presentedByModalCard: true
        )

        XCTAssertEqual(frame, CGRect(x: 0, y: 12, width: 390, height: 832))
    }
}
