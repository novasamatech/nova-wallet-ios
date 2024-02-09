import UIKit

final class NotificationsInteractor {
    weak var presenter: NotificationsInteractorOutputProtocol?
}

extension NotificationsInteractor: NotificationsInteractorInputProtocol {}