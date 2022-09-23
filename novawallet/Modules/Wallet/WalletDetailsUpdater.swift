import Foundation
import CommonWallet
import RobinHood

protocol WalletDetailsUpdating: AnyObject {
    var context: CommonWalletContextProtocol? { get }

    func setup(context: CommonWalletContextProtocol, chainAsset: ChainAsset)
}

final class WalletDetailsUpdater: WalletDetailsUpdating, EventVisitorProtocol {
    weak var context: CommonWalletContextProtocol? {
        didSet {
            clearProvidersIfNeeded()
        }
    }

    let eventCenter: EventCenterProtocol
    let crowdloansLocalSubscriptionFactory: CrowdloanContributionLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let walletSettings: SelectedWalletSettings

    private var crowdloanContributionsDataProvider: StreamableProvider<CrowdloanContributionData>?
    private var assetsLockDataProvider: StreamableProvider<AssetLock>?
    private var balanceDataProvider: StreamableProvider<AssetBalance>?

    init(
        eventCenter: EventCenterProtocol,
        crowdloansLocalSubscriptionFactory: CrowdloanContributionLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        walletSettings: SelectedWalletSettings
    ) {
        self.eventCenter = eventCenter
        self.crowdloansLocalSubscriptionFactory = crowdloansLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.walletSettings = walletSettings

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    func setup(context: CommonWalletContextProtocol, chainAsset: ChainAsset) {
        clearProviders()

        self.context = context

        if let wallet = walletSettings.value {
            subscribe(for: wallet, chainAsset: chainAsset)
        }
    }

    func processNewTransaction(event _: WalletNewTransactionInserted) {
        try? context?.prepareAccountUpdateCommand().execute()
    }

    private func subscribe(for wallet: MetaAccountModel, chainAsset: ChainAsset) {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        balanceDataProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )

        assetsLockDataProvider = subscribeToAllLocksProvider(for: accountId)

        crowdloanContributionsDataProvider = subscribeToCrowdloansProvider(for: accountId, chain: chainAsset.chain)
    }

    private func updateAccount() {
        try? context?.prepareAccountUpdateCommand().execute()
    }

    private func clearProvidersIfNeeded() {
        if context == nil {
            clearProviders()
        }
    }

    private func clearProviders() {
        balanceDataProvider = nil
        crowdloanContributionsDataProvider = nil
        assetsLockDataProvider = nil
    }
}

extension WalletDetailsUpdater: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result _: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        updateAccount()
    }

    func handleAccountLocks(result _: Result<[DataProviderChange<AssetLock>], Error>, accountId _: AccountId) {
        updateAccount()
    }
}

extension WalletDetailsUpdater: CrowdloanContributionLocalSubscriptionHandler, CrowdloansLocalStorageSubscriber {
    func handleCrowdloans(
        result _: Result<[DataProviderChange<CrowdloanContributionData>], Error>,
        accountId _: AccountId,
        chain _: ChainModel
    ) {
        updateAccount()
    }
}
