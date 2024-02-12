import Foundation

final class NotificationsSetupPresenter {
    weak var view: NotificationsSetupViewProtocol?
    let wireframe: NotificationsSetupWireframeProtocol
    let interactor: NotificationsSetupInteractorInputProtocol
    let legalData: LegalData

    init(
        interactor: NotificationsSetupInteractorInputProtocol,
        wireframe: NotificationsSetupWireframeProtocol,
        legalData: LegalData
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.legalData = legalData
    }
}

extension NotificationsSetupPresenter: NotificationsSetupPresenterProtocol {
    func setup() {}

    func enablePushNotifications() {
        interactor.enablePushNotifications()
    }

    func skip() {
        wireframe.complete(on: view)
    }

    func activateTerms() {
        guard let view = view else {
            return
        }
        wireframe.showWeb(
            url: legalData.termsUrl,
            from: view,
            style: .modal
        )
    }

    func activatePrivacy() {
        guard let view = view else {
            return
        }
        wireframe.showWeb(
            url: legalData.privacyPolicyUrl,
            from: view,
            style: .modal
        )
    }
}

extension NotificationsSetupPresenter: NotificationsSetupInteractorOutputProtocol {}
