import UIKit

final class NotificationsManagementInteractor {
    weak var presenter: NotificationsManagementInteractorOutputProtocol?
}

extension NotificationsManagementInteractor: NotificationsManagementInteractorInputProtocol {}
