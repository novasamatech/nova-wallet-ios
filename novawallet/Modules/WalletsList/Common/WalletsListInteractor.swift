import UIKit
import Operation_iOS

class WalletsListInteractor: WalletsListInteractorInputProtocol {
    weak var basePresenter: WalletsListInteractorOutputProtocol?

    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    let balancesStore: BalancesStoreProtocol
    let chainRegistry: ChainRegistryProtocol
    let walletFilter: WalletListFilterProtocol?

    private(set) var walletsSubscription: StreamableProvider<ManagedMetaAccountModel>?

    init(
        balancesStore: BalancesStoreProtocol,
        chainRegistry: ChainRegistryProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        walletFilter: WalletListFilterProtocol? = nil
    ) {
        self.balancesStore = balancesStore
        self.chainRegistry = chainRegistry
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.walletFilter = walletFilter
    }

    private func subscribeWallets() {
        walletsSubscription = subscribeAllWalletsProvider()
    }

    private func setupBalancesStore() {
        balancesStore.delegate = self
        balancesStore.setup()
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main,
            filterStrategy: .enabledChains
        ) { [weak self] changes in
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

    func filter(
        _ changes: [DataProviderChange<ManagedMetaAccountModel>]
    ) -> [DataProviderChange<ManagedMetaAccountModel>] {
        guard let walletFilter else { return changes }

        return walletFilter.apply(for: changes)
    }
}

extension WalletsListInteractor: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
    func handleAllWallets(result: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>) {
        switch result {
        case let .success(changes):
            applyWallets(changes: filter(changes))
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
