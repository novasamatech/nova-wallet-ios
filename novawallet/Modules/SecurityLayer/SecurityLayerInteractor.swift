import Foundation
import Keystore_iOS
import Foundation_iOS

final class SecurityLayerInteractor {
    let presenter: SecurityLayerInteractorOutputProtocol
    let keystore: KeystoreProtocol

    weak var service: SecurityLayerExecutionProtocol?

    private(set) var applicationHandler: ApplicationHandlerProtocol

    private var inactivityStart: Date?

    let inactivityDelay: TimeInterval

    private var canEnterPincode: Bool {
        do {
            let hasPincode = try keystore.checkKey(for: KeystoreTag.pincode.rawValue)
            return hasPincode
        } catch {
            return false
        }
    }

    init(
        presenter: SecurityLayerInteractorOutputProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        keystore: KeystoreProtocol,
        inactivityDelay: TimeInterval
    ) {
        self.presenter = presenter
        self.applicationHandler = applicationHandler
        self.keystore = keystore
        self.inactivityDelay = inactivityDelay
    }

    private func checkAuthorizationRequirement() {
        guard let inactivityStart = inactivityStart else {
            return
        }

        self.inactivityStart = nil

        if canEnterPincode {
            let inactivityDelayReached = Date().timeIntervalSince(inactivityStart) > inactivityDelay

            if inactivityDelayReached {
                presenter.didDecideRequestAuthorization()
            }
        }
    }
}

extension SecurityLayerInteractor: SecurityLayerInteractorInputProtocol {
    func setup() {
        applicationHandler.delegate = self
    }

    func completeAuthorization(for result: Bool) {
        service?.executeScheduledRequests(result)
    }
}

extension SecurityLayerInteractor: ApplicationHandlerDelegate {
    func didReceiveWillEnterForeground(notification _: Notification) {
        checkAuthorizationRequirement()
    }

    func didReceiveDidBecomeActive(notification _: Notification) {
        presenter.didDecideUnsecurePresentation()
        checkAuthorizationRequirement()
    }

    func didReceiveWillResignActive(notification _: Notification) {
        presenter.didDecideSecurePresentation()

        inactivityStart = Date()
    }

    func didReceiveDidEnterBackground(notification _: Notification) {
        // clear all pending requests if we go to background without authorization
        service?.executeScheduledRequests(false)
    }
}
