import UIKit

final class GovernanceNotificationsInteractor {
    weak var presenter: GovernanceNotificationsInteractorOutputProtocol?
    let chainRegistry: ChainRegistryProtocol

    init(
        chainRegistry: ChainRegistryProtocol
    ) {
        self.chainRegistry = chainRegistry
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main
        ) { [weak self] changes in
            let govChains = changes.filter {
                switch $0 {
                case let .insert(newItem), let .update(newItem):
                    return newItem.hasGovernanceV2
                case .delete:
                    return true
                }
            }
            self?.presenter?.didReceiveChainModel(changes: govChains)
        }
    }
}

extension GovernanceNotificationsInteractor: GovernanceNotificationsInteractorInputProtocol {
    func setup() {
        subscribeChains()
    }
}
