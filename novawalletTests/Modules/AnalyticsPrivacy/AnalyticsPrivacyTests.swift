import XCTest
import UIKit
import NovaAnalytics
@testable import novawallet

final class AnalyticsPrivacyTests: XCTestCase {
    func testSetupDeliversEnabledConsent() {
        let manager = PrivacyConsentStub(isEnabled: true, isAvailable: true)
        let output = PrivacyOutputSpy()
        let interactor = AnalyticsPrivacyInteractor(consentManager: manager)
        interactor.presenter = output

        interactor.setup()

        XCTAssertEqual(output.states.last?.isEnabled, true)
        XCTAssertEqual(output.states.last?.isAvailable, true)
        XCTAssertTrue(manager.consentQueue === DispatchQueue.main)
        XCTAssertTrue(manager.availabilityQueue === DispatchQueue.main)
    }

    func testEnableWhenAvailable() {
        let manager = PrivacyConsentStub(isEnabled: false, isAvailable: true)
        let interactor = AnalyticsPrivacyInteractor(consentManager: manager)

        interactor.setEnabled(true)

        XCTAssertEqual(manager.changes, [true])
    }

    func testDisableWhileUnavailable() {
        let manager = PrivacyConsentStub(isEnabled: true, isAvailable: false)
        let interactor = AnalyticsPrivacyInteractor(consentManager: manager)

        interactor.setEnabled(false)

        XCTAssertEqual(manager.changes, [false])
    }

    func testRejectedEnableRestoresCurrentConsent() {
        let manager = PrivacyConsentStub(isEnabled: false, isAvailable: false)
        let output = PrivacyOutputSpy()
        let interactor = AnalyticsPrivacyInteractor(consentManager: manager)
        interactor.presenter = output

        interactor.setEnabled(true)

        XCTAssertTrue(manager.changes.isEmpty)
        XCTAssertEqual(output.states.last?.isEnabled, false)
        XCTAssertEqual(output.states.last?.isAvailable, false)
    }

    func testExternalChangesRefreshState() {
        let manager = PrivacyConsentStub(isEnabled: false, isAvailable: true)
        let output = PrivacyOutputSpy()
        let interactor = AnalyticsPrivacyInteractor(consentManager: manager)
        interactor.presenter = output
        interactor.setup()

        manager.setEnabled(true)

        XCTAssertEqual(output.states.last?.isEnabled, true)
        XCTAssertEqual(output.states.last?.isAvailable, true)

        manager.isAvailable = false
        manager.availabilityObserver?(false)

        XCTAssertEqual(output.states.last?.isEnabled, true)
        XCTAssertEqual(output.states.last?.isAvailable, false)
    }

    func testDeinitRemovesObservers() {
        let manager = PrivacyConsentStub(isEnabled: false, isAvailable: true)
        var interactor: AnalyticsPrivacyInteractor? = AnalyticsPrivacyInteractor(consentManager: manager)
        interactor?.setup()

        interactor = nil

        XCTAssertTrue(manager.removedConsentObserver)
        XCTAssertTrue(manager.removedAvailabilityObserver)
    }

    func testPresenterAllowsWithdrawalWhileUnavailable() {
        let view = PrivacyViewSpy()
        let presenter = AnalyticsPrivacyPresenter(
            interactor: PrivacyInteractorSpy(),
            wireframe: PrivacyWireframeSpy(),
            privacyPolicyURL: URL(string: "https://example.com/privacy")!
        )
        presenter.view = view

        presenter.didReceive(isEnabled: true, isAvailable: false)

        XCTAssertEqual(view.isOn, true)
        XCTAssertEqual(view.canToggle, true)

        presenter.didReceive(isEnabled: false, isAvailable: false)

        XCTAssertEqual(view.isOn, false)
        XCTAssertEqual(view.canToggle, false)
    }

    func testPresenterStartsConsentObservation() {
        let interactor = PrivacyInteractorSpy()
        let presenter = AnalyticsPrivacyPresenter(
            interactor: interactor,
            wireframe: PrivacyWireframeSpy(),
            privacyPolicyURL: URL(string: "https://example.com/privacy")!
        )

        presenter.setup()

        XCTAssertTrue(interactor.didSetup)
    }

    func testPresenterForwardsConsentChange() {
        let interactor = PrivacyInteractorSpy()
        let presenter = AnalyticsPrivacyPresenter(
            interactor: interactor,
            wireframe: PrivacyWireframeSpy(),
            privacyPolicyURL: URL(string: "https://example.com/privacy")!
        )

        presenter.setEnabled(true)

        XCTAssertEqual(interactor.changes, [true])
    }

    func testPrivacyNoticeRoutesConfiguredURLFromCurrentView() {
        let view = PrivacyViewSpy()
        let wireframe = PrivacyWireframeSpy()
        let url = URL(string: "https://example.com/privacy")!
        let presenter = AnalyticsPrivacyPresenter(
            interactor: PrivacyInteractorSpy(),
            wireframe: wireframe,
            privacyPolicyURL: url
        )
        presenter.view = view

        presenter.showPrivacyNotice()

        XCTAssertEqual(wireframe.url, url)
        XCTAssertTrue(wireframe.view === view)
    }
}

private final class PrivacyOutputSpy: AnalyticsPrivacyInteractorOutputProtocol {
    var states: [(isEnabled: Bool, isAvailable: Bool)] = []

    func didReceive(isEnabled: Bool, isAvailable: Bool) {
        states.append((isEnabled, isAvailable))
    }
}

private final class PrivacyViewSpy: AnalyticsPrivacyViewProtocol {
    let controller = UIViewController()
    var isSetup: Bool { controller.isViewLoaded }
    var isOn: Bool?
    var canToggle: Bool?

    func didReceive(isOn: Bool, canToggle: Bool) {
        self.isOn = isOn
        self.canToggle = canToggle
    }
}

private final class PrivacyInteractorSpy: AnalyticsPrivacyInteractorInputProtocol {
    var didSetup = false
    var changes: [Bool] = []

    func setup() {
        didSetup = true
    }

    func setEnabled(_ enabled: Bool) {
        changes.append(enabled)
    }
}

private final class PrivacyWireframeSpy: AnalyticsPrivacyWireframeProtocol {
    var url: URL?
    weak var view: AnalyticsPrivacyViewProtocol?

    func showPrivacyNotice(from view: AnalyticsPrivacyViewProtocol?, url: URL) {
        self.view = view
        self.url = url
    }
}

private final class PrivacyConsentStub: AnalyticsConsentManagerProtocol {
    var isEnabled: Bool
    var isAvailable: Bool
    var isPromptSeen = true
    var isErasureOwed = false
    var changes: [Bool] = []
    var consentQueue: DispatchQueue?
    var availabilityQueue: DispatchQueue?
    var consentObserver: ((Bool, Bool) -> Void)?
    var availabilityObserver: ((Bool) -> Void)?
    var removedConsentObserver = false
    var removedAvailabilityObserver = false

    init(isEnabled: Bool, isAvailable: Bool) {
        self.isEnabled = isEnabled
        self.isAvailable = isAvailable
    }

    func setEnabled(_ enabled: Bool) {
        let previous = isEnabled
        changes.append(enabled)
        isEnabled = enabled
        consentObserver?(previous, enabled)
    }

    func setErasureOwed(_ owed: Bool) {
        isErasureOwed = owed
    }

    func markPromptSeen() {
        isPromptSeen = true
    }

    func addObserver(with _: AnyObject, queue: DispatchQueue?, closure: @escaping (Bool, Bool) -> Void) {
        consentQueue = queue
        consentObserver = closure
    }

    func removeObserver(by _: AnyObject) {
        removedConsentObserver = true
        consentObserver = nil
    }

    func addAvailabilityObserver(with _: AnyObject, queue: DispatchQueue?, closure: @escaping (Bool) -> Void) {
        availabilityQueue = queue
        availabilityObserver = closure
    }

    func removeAvailabilityObserver(by _: AnyObject) {
        removedAvailabilityObserver = true
        availabilityObserver = nil
    }
}
