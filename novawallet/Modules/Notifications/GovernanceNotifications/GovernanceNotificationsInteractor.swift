import UIKit
import Operation_iOS

final class GovernanceNotificationsInteractor {
    weak var presenter: GovernanceNotificationsInteractorOutputProtocol?

    let fetchOperationFactory: ReferendumsOperationFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        fetchOperationFactory: ReferendumsOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.fetchOperationFactory = fetchOperationFactory
        self.operationQueue = operationQueue
    }

    private func provideTracks(for chain: ChainModel) {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return
        }

        let wrapper = fetchOperationFactory.fetchAllTracks(runtimeProvider: runtimeProvider)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(tracks):
                self?.presenter?.didReceiveTracks(tracks, for: chain)
            case let .failure(error):
                self?.presenter?.didReceive(trackFetchError: error, for: chain)
            }
        }
    }

    private func provideTracks(from changes: [DataProviderChange<ChainModel>]) {
        for change in changes {
            switch change {
            case let .insert(chain), let .update(chain):
                provideTracks(for: chain)
            case .delete:
                break
            }
        }
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main
        ) { [weak self] changes in
            let govChains = changes.filter {
                switch $0 {
                case let .insert(newItem), let .update(newItem):
                    return newItem.hasPushNotifications && newItem.hasGovernanceV2
                case .delete:
                    return true
                }
            }

            self?.provideTracks(from: govChains)
            self?.presenter?.didReceiveChainModel(changes: govChains)
        }
    }
}

extension GovernanceNotificationsInteractor: GovernanceNotificationsInteractorInputProtocol {
    func setup() {
        subscribeChains()
    }
}
