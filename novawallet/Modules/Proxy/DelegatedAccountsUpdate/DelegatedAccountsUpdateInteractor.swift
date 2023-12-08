import UIKit
import RobinHood

final class DelegatedAccountsUpdateInteractor {
    weak var presenter: DelegatedAccountsUpdateInteractorOutputProtocol?
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    let chainRegistry: ChainRegistryProtocol

    private(set) var walletsSubscription: StreamableProvider<ManagedMetaAccountModel>?
    private(set) var allChains: [ChainModel.Id: ChainModel] = [:]

    init(
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.chainRegistry = chainRegistry
    }

    private func subscribeWallets() {
        walletsSubscription = subscribeAllWalletsProvider()
    }

    func subscribeChains() {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            self?.presenter?.didReceiveChainChanges(changes)
        }
    }
}

extension DelegatedAccountsUpdateInteractor: DelegatedAccountsUpdateInteractorInputProtocol {
    func setup() {
        subscribeWallets()
        subscribeChains()
    }
}

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
