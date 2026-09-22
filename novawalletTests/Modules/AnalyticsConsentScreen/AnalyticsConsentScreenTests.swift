import XCTest
import UIKit
@testable import novawallet

final class AnalyticsConsentScreenTests: XCTestCase {
    func testMissingPresentingViewReportsUnavailableWithoutRecordingDecision() {
        let wireframe = MainTabBarWireframe(cardScreenNavigationFactory: CardScreenNavigationFactory())
        var unavailableCount = 0
        var decisionCount = 0

        wireframe.presentAnalyticsConsent(
            from: nil,
            onEnable: { decisionCount += 1 },
            onDecline: { decisionCount += 1 },
            onUnavailable: { unavailableCount += 1 }
        )

        XCTAssertEqual(unavailableCount, 1)
        XCTAssertEqual(decisionCount, 0)
    }

    func testAgreeCompletesOnlyOnce() {
        let wireframe = ConsentWireframeSpy()
        let presenter = makePresenter(wireframe: wireframe)

        presenter.agree()
        presenter.decline()
        presenter.agree()

        XCTAssertEqual(wireframe.decisions, [true])
    }

    func testDeclineCompletesOnlyOnce() {
        let wireframe = ConsentWireframeSpy()
        let presenter = makePresenter(wireframe: wireframe)

        presenter.decline()
        presenter.agree()

        XCTAssertEqual(wireframe.decisions, [false])
    }

    func testPrivacyNoticeOpensConfiguredURLWithoutMakingDecision() {
        let wireframe = ConsentWireframeSpy()
        let presenter = makePresenter(wireframe: wireframe)

        presenter.showPrivacyNotice()

        XCTAssertEqual(wireframe.openedURL?.absoluteString, "https://example.org/privacy")
        XCTAssertTrue(wireframe.decisions.isEmpty)
    }

    func testAgreeCallsEnableAfterDismissalCompletes() {
        var decisions: [Bool] = []
        let wireframe = AnalyticsConsentScreenWireframe(
            onEnable: { decisions.append(true) },
            onDecline: { decisions.append(false) }
        )
        let view = ConsentViewSpy()

        wireframe.complete(from: view, enabled: true)

        XCTAssertEqual(view.dismissCount, 1)
        XCTAssertTrue(decisions.isEmpty)
        view.dismissCompletion?()
        XCTAssertEqual(decisions, [true])
    }

    func testDeclineCallsDeclineAfterDismissalCompletes() {
        var decisions: [Bool] = []
        let wireframe = AnalyticsConsentScreenWireframe(
            onEnable: { decisions.append(true) },
            onDecline: { decisions.append(false) }
        )
        let view = ConsentViewSpy()

        wireframe.complete(from: view, enabled: false)

        XCTAssertTrue(decisions.isEmpty)
        view.dismissCompletion?()
        XCTAssertEqual(decisions, [false])
    }

    func testFactoryRequiresExplicitChoiceWithoutBackNavigation() throws {
        var decisionCount = 0
        let view = try XCTUnwrap(AnalyticsConsentScreenViewFactory.createView(
            onEnable: { decisionCount += 1 },
            onDecline: { decisionCount += 1 }
        ))

        XCTAssertEqual(view.controller.modalPresentationStyle, .fullScreen)
        XCTAssertTrue(view.controller.isModalInPresentation)
        XCTAssertNil(view.controller.navigationItem.leftBarButtonItem)
        XCTAssertNil(view.controller.navigationItem.rightBarButtonItem)
        XCTAssertEqual(decisionCount, 0)
    }

    private func makePresenter(wireframe: ConsentWireframeSpy) -> AnalyticsConsentScreenPresenter {
        AnalyticsConsentScreenPresenter(
            interactor: AnalyticsConsentScreenInteractor(),
            wireframe: wireframe,
            privacyPolicyURL: URL(string: "https://example.org/privacy")!
        )
    }
}

private final class ConsentWireframeSpy: AnalyticsConsentScreenWireframeProtocol {
    var decisions: [Bool] = []
    var openedURL: URL?

    func complete(from _: AnalyticsConsentScreenViewProtocol?, enabled: Bool) {
        decisions.append(enabled)
    }

    func showPrivacyNotice(from _: AnalyticsConsentScreenViewProtocol?, url: URL) {
        openedURL = url
    }
}

private final class ConsentViewSpy: UIViewController, AnalyticsConsentScreenViewProtocol {
    var dismissCount = 0
    var dismissCompletion: (() -> Void)?

    override func dismiss(animated _: Bool, completion: (() -> Void)? = nil) {
        dismissCount += 1
        dismissCompletion = completion
    }
}
