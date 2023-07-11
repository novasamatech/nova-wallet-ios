import UIKit
import RobinHood
import BigInt

class StartStakingInfoBaseInteractor: StartStakingInfoInteractorInputProtocol, AnyProviderAutoCleaning {
    weak var basePresenter: StartStakingInfoInteractorOutputProtocol?
    let selectedChainAsset: ChainAsset
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let selectedWalletSettings: SelectedWalletSettings

    private(set) var priceProvider: StreamableProvider<PriceData>?
    private(set) var balanceProvider: StreamableProvider<AssetBalance>?
    private(set) var selectedAccount: MetaChainAccountResponse?
    private(set) var operationQueue: OperationQueue

    init(
        selectedWalletSettings: SelectedWalletSettings,
        selectedChainAsset: ChainAsset,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.selectedChainAsset = selectedChainAsset
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
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
            basePresenter?.didReceive(baseError: .assetBalance(nil))
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
        
        basePresenter?.didReceive(account: selectedAccount?.chainAccount.accountId)
    }

    func setup() {
        setupSelectedAccount()
        performAssetBalanceSubscription()
        performPriceSubscription()

        basePresenter?.didReceive(chainAsset: selectedChainAsset)
    }

    func remakeSubscriptions() {
        performAssetBalanceSubscription()
        performPriceSubscription()
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
