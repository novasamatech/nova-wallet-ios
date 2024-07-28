import UIKit

final class StakingRewardsNotificationsInteractor {
    weak var presenter: StakingRewardsNotificationsInteractorOutputProtocol?
    let chainRegistry: ChainRegistryProtocol

    init(
        chainRegistry: ChainRegistryProtocol
    ) {
        self.chainRegistry = chainRegistry
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main,
            filterStrategy: .enabledChains
        ) { [weak self] changes in
            let stakingChains = changes.filter {
                switch $0 {
                case let .insert(newItem), let .update(newItem):
                    return newItem.hasPushNotifications && newItem.hasStaking
                case .delete:
                    return true
                }
            }
            self?.presenter?.didReceiveChainModel(changes: stakingChains)
        }
    }
}

extension StakingRewardsNotificationsInteractor: StakingRewardsNotificationsInteractorInputProtocol {
    func setup() {
        subscribeChains()
    }
}
