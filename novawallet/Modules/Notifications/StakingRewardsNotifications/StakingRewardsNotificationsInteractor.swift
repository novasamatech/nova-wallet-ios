import UIKit

final class StakingRewardsNotificationsInteractor {
    weak var presenter: StakingRewardsNotificationsInteractorOutputProtocol?
}

extension StakingRewardsNotificationsInteractor: StakingRewardsNotificationsInteractorInputProtocol {}
