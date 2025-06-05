import UIKit
import Operation_iOS

final class DelegatedAccountsUpdateInteractor {
    weak var presenter: DelegatedAccountsUpdateInteractorOutputProtocol?
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    let chainRegistry: ChainRegistryProtocol

    private(set) var walletsSubscription: StreamableProvider<ManagedMetaAccountModel>?

    init(
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.chainRegistry = chainRegistry
    }
}

// MARK: - Private

private extension DelegatedAccountsUpdateInteractor {
    func subscribeWallets() {
        walletsSubscription = subscribeAllWalletsProvider()
    }

    func subscribeChains() {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            self?.presenter?.didReceiveChainChanges(changes)
        }
    }
}

// MARK: - DelegatedAccountsUpdateInteractorInputProtocol

extension DelegatedAccountsUpdateInteractor: DelegatedAccountsUpdateInteractorInputProtocol {
    func setup() {
        subscribeWallets()
        subscribeChains()
    }
}

// MARK: - WalletListLocalStorageSubscriber

extension DelegatedAccountsUpdateInteractor: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
    func handleAllWallets(result: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>) {
        switch result {
        case let .success(changes):
            presenter?.didReceiveWalletsChanges(changes)
        case let .failure(error):
            presenter?.didReceiveError(.subscription(error))
        }
    }
}
