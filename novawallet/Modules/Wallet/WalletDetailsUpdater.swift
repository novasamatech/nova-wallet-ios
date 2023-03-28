import Foundation
import CommonWallet
import RobinHood

protocol WalletDetailsUpdating: AnyObject {
    var context: CommonWalletContextProtocol? { get }

    func setup(context: CommonWalletContextProtocol, chainAsset: ChainAsset)
}

/**
 *  Class is responsible for monitoring balance or transaction changes
 *  and ask CommonWallet to update itself.
 *
 *  Note: Currently there is no way to know whether CommonWallet was closed.
 *  So, before processing the event we should manually check whether context
 *  exists and clear observers otherwise.
 */

final class WalletDetailsUpdater: WalletDetailsUpdating, EventVisitorProtocol {
    weak var context: CommonWalletContextProtocol?

    let eventCenter: EventCenterProtocol
    let crowdloansLocalSubscriptionFactory: CrowdloanContributionLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let walletSettings: SelectedWalletSettings
    let currencyManager: CurrencyManager

    private var crowdloanContributionsDataProvider: StreamableProvider<CrowdloanContributionData>?
    private var assetsLockDataProvider: StreamableProvider<AssetLock>?
    private var balanceDataProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?

    init(
        eventCenter: EventCenterProtocol,
        crowdloansLocalSubscriptionFactory: CrowdloanContributionLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletSettings: SelectedWalletSettings,
        currencyManager: CurrencyManager
    ) {
        self.eventCenter = eventCenter
        self.crowdloansLocalSubscriptionFactory = crowdloansLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.walletSettings = walletSettings
        self.currencyManager = currencyManager

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    func setup(context: CommonWalletContextProtocol, chainAsset: ChainAsset) {
        clearProviders()

        self.context = context

        if let wallet = walletSettings.value {
            subscribe(for: wallet, chainAsset: chainAsset)
        }
    }

    func processTransactionHistoryUpdate(event _: WalletTransactionListUpdated) {
        try? context?.prepareAccountUpdateCommand().execute()
    }

    func processAssetBalanceChanged(event _: AssetBalanceChanged) {
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

        assetsLockDataProvider = subscribeToLocksProvider(
            for: accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )

        if chainAsset.chain.hasCrowdloans {
            crowdloanContributionsDataProvider = subscribeToCrowdloansProvider(for: accountId, chain: chainAsset.chain)
        }

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: currencyManager.selectedCurrency)
        }
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
        priceProvider = nil
    }
}

extension WalletDetailsUpdater: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result _: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        clearProvidersIfNeeded()
        updateAccount()
    }

    func handleAccountLocks(
        result _: Result<[DataProviderChange<AssetLock>], Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        clearProvidersIfNeeded()
        updateAccount()
    }
}

extension WalletDetailsUpdater: CrowdloanContributionLocalSubscriptionHandler, CrowdloansLocalStorageSubscriber {
    func handleCrowdloans(
        result _: Result<[DataProviderChange<CrowdloanContributionData>], Error>,
        accountId _: AccountId,
        chain _: ChainModel
    ) {
        clearProvidersIfNeeded()
        updateAccount()
    }
}

extension WalletDetailsUpdater: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result _: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        clearProvidersIfNeeded()
        updateAccount()
    }
}
