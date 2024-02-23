import Foundation

final class NotificationsSetupPresenter {
    weak var view: NotificationsSetupViewProtocol?
    let wireframe: NotificationsSetupWireframeProtocol
    let interactor: NotificationsSetupInteractorInputProtocol
    let legalData: LegalData
    weak var delegate: PushNotificationsStatusDelegate?

    init(
        interactor: NotificationsSetupInteractorInputProtocol,
        wireframe: NotificationsSetupWireframeProtocol,
        legalData: LegalData,
        delegate: PushNotificationsStatusDelegate?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.legalData = legalData
        self.delegate = delegate
    }
}

extension NotificationsSetupPresenter: NotificationsSetupPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func enablePushNotifications() {
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
        delegate?.pushNotificationsStatusDidUpdate()
        wireframe.complete(on: view)
    }
}
