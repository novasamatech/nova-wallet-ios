import UIKit

final class GovernanceNotificationsInteractor {
    weak var presenter: GovernanceNotificationsInteractorOutputProtocol?
}

extension GovernanceNotificationsInteractor: GovernanceNotificationsInteractorInputProtocol {}
