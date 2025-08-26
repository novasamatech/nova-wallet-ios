import UIKit
import Operation_iOS

final class NotificationWalletListInteractor: AnyProviderAutoCleaning {
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
}

// MARK: - Private

private extension NotificationWalletListInteractor {
    func subscribeWallets() {
        walletsSubscription = subscribeAllWalletsProvider()
    }

    func subscribeChains() {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            self?.presenter?.didReceiveChainChanges(changes)
        }
    }
}

// MARK: - NotificationWalletListInteractorInputProtocol

extension NotificationWalletListInteractor: NotificationWalletListInteractorInputProtocol {
    func setup() {
        subscribeChains()
        subscribeWallets()
    }
}

// MARK: - WalletListLocalSubscriptionHandler

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
