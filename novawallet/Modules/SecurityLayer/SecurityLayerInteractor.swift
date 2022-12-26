import Foundation
import SoraKeystore
import SoraFoundation

final class SecurityLayerInteractor {
    let presenter: SecurityLayerInteractorOutputProtocol
    let settings: SettingsManagerProtocol
    let keystore: KeystoreProtocol

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
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol,
        inactivityDelay: TimeInterval
    ) {
        self.presenter = presenter
        self.applicationHandler = applicationHandler
        self.settings = settings
        self.keystore = keystore
        self.inactivityDelay = inactivityDelay
    }

    private func checkAuthorizationRequirement() {
        guard let inactivityStart = inactivityStart else {
            return
        }

        self.inactivityStart = nil

        if canEnterPincode {
            let inactivityDelayReached = Date().timeIntervalSince(inactivityStart) >= inactivityDelay

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
}
