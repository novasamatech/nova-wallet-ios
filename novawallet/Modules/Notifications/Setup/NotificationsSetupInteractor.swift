import UIKit

final class NotificationsSetupInteractor {
    weak var presenter: NotificationsSetupInteractorOutputProtocol?

    let pushNotificationsService: PushNotificationsServiceProtocol

    init(pushNotificationsService: PushNotificationsServiceProtocol) {
        self.pushNotificationsService = pushNotificationsService
    }

    func provideStatus() {
        pushNotificationsService.status { [weak self] status in
            DispatchQueue.main.async {
                self?.presenter?.didRegister(notificationStatus: status)
            }
        }
    }
}

extension NotificationsSetupInteractor: NotificationsSetupInteractorInputProtocol {
    func setup() {
        pushNotificationsService.setup()
    }

    func enablePushNotifications() {
        pushNotificationsService.register { [weak self] in
            self?.provideStatus()
        }
    }
}
