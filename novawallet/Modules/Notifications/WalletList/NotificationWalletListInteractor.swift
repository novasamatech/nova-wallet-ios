import UIKit
import RobinHood

final class NotificationWalletListInteractor {
    weak var presenter: NotificationWalletListInteractorOutputProtocol?
    let chainRegistry: ChainRegistryProtocol
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    private var walletsSubscription: StreamableProvider<ManagedMetaAccountModel>?

    init(
        chainRegistry: ChainRegistryProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
    }

    private func subscribeWallets() {
        walletsSubscription = subscribeAllWalletsProvider()
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            self?.presenter?.didReceiveChainChanges(changes)
        }
    }
}

extension NotificationWalletListInteractor: NotificationWalletListInteractorInputProtocol {
    func setup() {
        subscribeChains()
        subscribeWallets()
    }
}

extension NotificationWalletListInteractor: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
    func handleAllWallets(result: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>) {
        switch result {
        case let .success(changes):
            presenter?.didReceiveWalletsChanges(changes)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}
