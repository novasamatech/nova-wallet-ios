import UIKit
import RobinHood

class WalletsListInteractor: WalletsListInteractorInputProtocol {
    weak var basePresenter: WalletsListInteractorOutputProtocol?

    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    let balancesStore: BalancesStoreProtocol
    let chainRegistry: ChainRegistryProtocol

    private(set) var walletsSubscription: StreamableProvider<ManagedMetaAccountModel>?

    init(
        balancesStore: BalancesStoreProtocol,
        chainRegistry: ChainRegistryProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    ) {
        self.balancesStore = balancesStore
        self.chainRegistry = chainRegistry
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
    }

    private func subscribeWallets() {
        walletsSubscription = subscribeAllWalletsProvider()
    }

    private func setupBalancesStore() {
        balancesStore.delegate = self
        balancesStore.setup()
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            self?.basePresenter?.didReceiveChainChanges(changes)
        }
    }

    func applyWallets(changes: [DataProviderChange<ManagedMetaAccountModel>]) {
        basePresenter?.didReceiveWalletsChanges(changes)
    }

    func setup() {
        subscribeChains()
        subscribeWallets()
        setupBalancesStore()
    }
}

extension WalletsListInteractor: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
    func handleAllWallets(result: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>) {
        switch result {
        case let .success(changes):
            applyWallets(changes: changes)
        case let .failure(error):
            basePresenter?.didReceiveError(error)
        }
    }
}

extension WalletsListInteractor: BalancesStoreDelegate {
    func balancesStore(_: BalancesStoreProtocol, didUpdate calculator: BalancesCalculating) {
        basePresenter?.didUpdateBalancesCalculator(calculator)
    }

    func balancesStore(_: BalancesStoreProtocol, didReceive error: BalancesStoreError) {
        basePresenter?.didReceiveError(error)
    }
}
