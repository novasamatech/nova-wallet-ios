import Foundation
import RobinHood

class ParaStkYieldBoostCommonInteractor {
    weak var presenter: ParaStkYieldBoostCommonInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: ChainAccountResponse
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let yieldBoostProviderFactory: ParaStkYieldBoostProviderFactoryProtocol

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var yieldBoostProvider: AnySingleValueProvider<[ParaStkYieldBoostState.Task]>?

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        yieldBoostProviderFactory: ParaStkYieldBoostProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.yieldBoostProviderFactory = yieldBoostProviderFactory
        self.currencyManager = currencyManager
    }

    private func performSubscription() {
        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )

        yieldBoostProvider = subscribeYieldBoostTasks(
            for: chainAsset.chain.chainId,
            accountId: selectedAccount.accountId
        )

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }
}

extension ParaStkYieldBoostCommonInteractor: ParaStkYieldBoostCommonInteractorInputProtocol {
    func setup() {
        performSubscription()
    }

    func retryCommonSubscriptions() {
        performSubscription()
    }
}

extension ParaStkYieldBoostCommonInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            presenter?.didReceiveAsset(balance: balance)
        case let .failure(error):
            presenter?.didReceiveCommonInteractor(error: .balanceSubscriptionFailed(error))
        }
    }
}

extension ParaStkYieldBoostCommonInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceiveAsset(price: priceData)
        case let .failure(error):
            presenter?.didReceiveCommonInteractor(error: .priceSubscriptionFailed(error))
        }
    }
}

extension ParaStkYieldBoostCommonInteractor: ParaStkYieldBoostStorageSubscriber, ParaStkYieldBoostSubscriptionHandler {
    func handleYieldBoostTasks(
        result: Result<[ParaStkYieldBoostState.Task]?, Error>,
        chainId _: ChainModel.Id,
        accountId _: AccountId
    ) {
        switch result {
        case let .success(tasks):
            presenter?.didReceiveYieldBoost(tasks: tasks)
        case let .failure(error):
            presenter?.didReceiveCommonInteractor(error: .yieldBoostTasksSubscriptionFailed(error))
        }
    }
}

extension ParaStkYieldBoostCommonInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
