import UIKit
import Operation_iOS
import SubstrateSdk
import SoraKeystore

final class NetworksListInteractor {
    weak var presenter: NetworksListInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let settingsManager: SettingsManagerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        settingsManager: SettingsManagerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.settingsManager = settingsManager
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main
        ) { [weak self] changes in
            guard let self else { return }

            changes.forEach { change in
                switch change {
                case let .insert(newItem):
                    self.chainRegistry.subscribeChainState(
                        self,
                        chainId: newItem.chainId
                    )
                case let .delete(deletedIdentifier):
                    self.chainRegistry.unsubscribeChainState(
                        self,
                        chainId: deletedIdentifier
                    )

                default:
                    break
                }
            }

            presenter?.didReceiveChains(changes: changes)
        }
    }
}

extension NetworksListInteractor: NetworksListInteractorInputProtocol {
    func provideChains() {
        subscribeChains()
    }

    func setIntegrationBannerSeen() {
        settingsManager.integrateNetworksBannerSeen = true
    }
}

extension NetworksListInteractor: ConnectionStateSubscription {
    func didReceive(
        state: WebSocketEngine.State,
        for chainId: ChainModel.Id
    ) {
        let connectionState: NetworksListPresenter.ConnectionState = switch state {
        case .notConnected, .connecting, .waitingReconnection:
            .connecting
        case .connected:
            .connected
        }

        presenter?.didReceive(connectionState: connectionState, for: chainId)
    }
}
