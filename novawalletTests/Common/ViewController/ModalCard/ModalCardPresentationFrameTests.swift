import XCTest
@testable import novawallet

final class ModalCardPresentationFrameTests: XCTestCase {
    private let container = CGRect(x: 0, y: 0, width: 390, height: 844)

    func testFirstLevelCardFillsContainerBelowTopOffset() {
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

    func testCardPresentedFromBottomSheetIsStillFullHeight() {
        // A bottom sheet's view is only the pane, but the card lives in the full-size container,
        // so the frame must come from the container, never from the presenting view (NW-2379).
        let frame = ModalCardPresentationController.presentedViewFrame(
            containerBounds: container,
            safeAreaTop: 47,
            presentedByModalCard: false
        )

        XCTAssertEqual(frame.height, container.height - 47 - 12)
        XCTAssertEqual(frame.maxY, container.height)
    }
}
