import Foundation
import SoraKeystore
import SoraFoundation

final class SecurityLayerService {
    static let inactivityTimeoutInMinutes: TimeInterval = 5.0
    static let inactivityDelayInSeconds: TimeInterval = inactivityTimeoutInMinutes.secondsFromMinutes

    static let sharedInteractor: SecurityLayerInteractorInputProtocol = {
        let wireframe = SecurityLayerWireframe()
        let presenter = SecurityLayerPresenter(wireframe: wireframe)

        let interactor = SecurityLayerInteractor(
            presenter: presenter,
            applicationHandler: ApplicationHandler(),
            settings: SettingsManager.shared,
            keystore: Keychain(),
            inactivityDelay: inactivityDelayInSeconds
        )

        presenter.interactor = interactor

        return interactor
    }()
}
