import UIKit

final class NotificationsSetupInteractor {
    weak var presenter: NotificationsSetupInteractorOutputProtocol?
}

extension NotificationsSetupInteractor: NotificationsSetupInteractorInputProtocol {
    func enablePushNotifications() {}
}
