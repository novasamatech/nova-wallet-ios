import Foundation
import Foundation_iOS

final class NotificationsSetupPresenter {
    weak var view: NotificationsSetupViewProtocol?
    let wireframe: NotificationsSetupWireframeProtocol
    let interactor: NotificationsSetupInteractorInputProtocol
    let legalData: LegalData
    let localizationManager: LocalizationManagerProtocol

    init(
        interactor: NotificationsSetupInteractorInputProtocol,
        wireframe: NotificationsSetupWireframeProtocol,
        legalData: LegalData,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.legalData = legalData
        self.localizationManager = localizationManager
    }
}

extension NotificationsSetupPresenter: NotificationsSetupPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func enablePushNotifications() {
        view?.didStartEnabling()
        interactor.enablePushNotifications()
    }

    func skip() {
        wireframe.complete(on: view)
    }

    func activateTerms() {
        wireframe.show(url: legalData.termsUrl, from: view)
    }

    func activatePrivacy() {
        wireframe.show(url: legalData.privacyPolicyUrl, from: view)
    }
}

extension NotificationsSetupPresenter: NotificationsSetupInteractorOutputProtocol {
    func didRegister(notificationStatus _: PushNotificationsStatus) {
        wireframe.saved(on: view)
    }

    func didReceive(error: Error) {
        switch error {
        case let PushNotificationsServiceFacadeError.settingsUpdateFailed(internalError):
            if internalError is PushNotificationsStatusServiceError {
                wireframe.complete(on: view)
                return
            }
        default:
            view?.didStopEnabling()

            wireframe.presentRequestStatus(
                on: view,
                locale: localizationManager.selectedLocale
            ) { [weak self] in
                self?.interactor.enablePushNotifications()
            }
        }
    }
}
