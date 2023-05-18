import UIKit
import RobinHood

class WalletsListInteractor {
    weak var basePresenter: WalletsListInteractorOutputProtocol?

    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    let balancesStore: BalancesStoreProtocol

    private(set) var walletsSubscription: StreamableProvider<ManagedMetaAccountModel>?

    init(
        balancesStore: BalancesStoreProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    ) {
        self.balancesStore = balancesStore
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
    }

    private func subscribeWallets() {
        walletsSubscription = subscribeAllWalletsProvider()
    }

    private func setupBalancesStore() {
        balancesStore.delegate = self
        balancesStore.setup()
    }
}

extension WalletsListInteractor: WalletsListInteractorInputProtocol {
    func setup() {
        subscribeWallets()
        setupBalancesStore()
    }
}

extension WalletsListInteractor: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
    func handleAllWallets(result: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>) {
        switch result {
        case let .success(changes):
            basePresenter?.didReceiveWalletsChanges(changes)
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
