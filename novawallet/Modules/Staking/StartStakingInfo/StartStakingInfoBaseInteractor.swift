import UIKit
import Operation_iOS
import BigInt

class StartStakingInfoBaseInteractor: StartStakingInfoInteractorInputProtocol, AnyProviderAutoCleaning {
    weak var basePresenter: StartStakingInfoInteractorOutputProtocol?
    let selectedChainAsset: ChainAsset
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol
    let selectedWalletSettings: SelectedWalletSettings
    let selectedStakingType: StakingType?
    let sharedOperation: SharedOperationStatusProtocol

    private(set) var priceProvider: StreamableProvider<PriceData>?
    private(set) var balanceProvider: StreamableProvider<AssetBalance>?
    private(set) var stakingStateProvider: StreamableProvider<Multistaking.DashboardItem>?
    private(set) var selectedAccount: MetaChainAccountResponse?
    private(set) var operationQueue: OperationQueue

    init(
        selectedWalletSettings: SelectedWalletSettings,
        selectedChainAsset: ChainAsset,
        selectedStakingType: StakingType?,
        sharedOperation: SharedOperationStatusProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.selectedChainAsset = selectedChainAsset
        self.selectedStakingType = selectedStakingType
        self.sharedOperation = sharedOperation
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.stakingDashboardProviderFactory = stakingDashboardProviderFactory
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    private func performPriceSubscription() {
        clear(streamableProvider: &priceProvider)

        guard let priceId = selectedChainAsset.asset.priceId else {
            basePresenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    private func performAssetBalanceSubscription() {
        clear(streamableProvider: &balanceProvider)

        let chainAssetId = selectedChainAsset.chainAssetId

        guard let accountId = selectedAccount?.chainAccount.accountId else {
            return
        }

        balanceProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId
        )
    }

    private func setupSelectedAccount() {
        guard let wallet = selectedWalletSettings.value else {
            return
        }

        selectedAccount = wallet.fetchMetaChainAccount(
            for: selectedChainAsset.chain.accountRequest()
        )

        basePresenter?.didReceive(wallet: wallet, chainAccountId: selectedAccount?.chainAccount.accountId)
    }

    private func performStakingStateSubscription() {
        stakingStateProvider?.removeObserver(self)

        guard let wallet = selectedWalletSettings.value else {
            return
        }

        stakingStateProvider = subscribeDashboardItems(
            for: wallet.metaId,
            chainAssetId: selectedChainAsset.chainAssetId
        )
    }

    func setup() {
        setupSelectedAccount()

        performAssetBalanceSubscription()
        performPriceSubscription()
        performStakingStateSubscription()
    }

    func remakeSubscriptions() {
        performAssetBalanceSubscription()
        performPriceSubscription()
        performStakingStateSubscription()
    }
}

extension StartStakingInfoBaseInteractor: StakingDashboardLocalStorageSubscriber,
    StakingDashboardLocalStorageHandler {
    func handleDashboardItems(
        _ result: Result<[DataProviderChange<Multistaking.DashboardItem>], Error>,
        walletId _: MetaAccountModel.Id,
        chainAssetId _: ChainAssetId
    ) {
        switch result {
        case let .success(changes):
            let stakingOption = changes.first { change in
                switch change {
                case let .insert(newItem), let .update(newItem):
                    guard let currentStakingType = selectedStakingType else {
                        return newItem.hasStaking
                    }

                    return currentStakingType == newItem.stakingOption.option.type && newItem.hasStaking
                case .delete:
                    return false
                }
            }

            // if staking is already enabled by external app we need to notify a user about it
            if stakingOption != nil, sharedOperation.isComposing {
                basePresenter?.didReceiveStakingEnabled()
            }
        case let .failure(error):
            basePresenter?.didReceive(baseError: .stakingState(error))
        }
    }
}

extension StartStakingInfoBaseInteractor: WalletLocalStorageSubscriber,
    WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard
            chainId == selectedChainAsset.chain.chainId,
            assetId == selectedChainAsset.asset.assetId,
            accountId == selectedAccount?.chainAccount.accountId else {
            return
        }

        switch result {
        case let .success(balance):
            let balance = balance ?? .createZero(
                for: .init(chainId: chainId, assetId: assetId),
                accountId: accountId
            )
            basePresenter?.didReceive(assetBalance: balance)
        case let .failure(error):
            basePresenter?.didReceive(baseError: .assetBalance(error))
        }
    }
}

extension StartStakingInfoBaseInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        if selectedChainAsset.asset.priceId == priceId {
            switch result {
            case let .success(priceData):
                basePresenter?.didReceive(price: priceData)
            case let .failure(error):
                basePresenter?.didReceive(baseError: .price(error))
            }
        }
    }
}

extension StartStakingInfoBaseInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard basePresenter != nil,
              let priceId = selectedChainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
