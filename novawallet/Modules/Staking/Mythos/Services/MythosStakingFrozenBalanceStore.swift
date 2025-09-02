import Foundation
import Operation_iOS

final class MythosStakingFrozenBalanceStore: BaseObservableStateStore<MythosStakingFrozenBalance> {
    let accountId: AccountId
    let chainAssetId: ChainAssetId
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol

    private var locksProvider: StreamableProvider<AssetLock>?
    private var locks: [String: AssetLock]?

    init(
        accountId: AccountId,
        chainAssetId: ChainAssetId,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.accountId = accountId
        self.chainAssetId = chainAssetId
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory

        super.init(logger: logger)
    }

    private func makeSubscription() {
        locksProvider?.removeObserver(self)

        locksProvider = subscribeToLocksProvider(
            for: accountId,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId
        )
    }
}

extension MythosStakingFrozenBalanceStore: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountLocks(
        result: Result<[DataProviderChange<AssetLock>], Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(changes):
            locks = changes.mergeToDict(locks ?? [:])
            stateObservable.state = MythosStakingFrozenBalance(locks: Array((locks ?? [:]).values))

        case let .failure(error):
            logger.error("Locks subscription failed: \(error)")
        }
    }
}

extension MythosStakingFrozenBalanceStore: ApplicationServiceProtocol {
    func setup() {
        makeSubscription()
    }

    func throttle() {
        locksProvider = nil
    }
}
