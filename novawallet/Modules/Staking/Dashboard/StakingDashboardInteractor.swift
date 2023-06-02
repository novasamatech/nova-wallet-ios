import UIKit

final class StakingDashboardInteractor {
    weak var presenter: StakingDashboardInteractorOutputProtocol?
}

extension StakingDashboardInteractor: StakingDashboardInteractorInputProtocol {}