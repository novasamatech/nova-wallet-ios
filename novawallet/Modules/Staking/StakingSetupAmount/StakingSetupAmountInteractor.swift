import UIKit
import RobinHood

final class StakingSetupAmountInteractor: AnyProviderAutoCleaning {
    weak var presenter: StakingSetupAmountInteractorOutputProtocol?

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

    deinit {
        clear(streamableProvider: &priceProvider)
        clear(streamableProvider: &balanceProvider)
    }

    private func performPriceSubscription() {
        clear(streamableProvider: &priceProvider)

        guard let priceId = selectedChainAsset.asset.priceId else {
            presenter?.didReceive(price: nil)
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
    }
}

extension StakingSetupAmountInteractor: StakingSetupAmountInteractorInputProtocol {
    func setup() {
        setupSelectedAccount()
        performAssetBalanceSubscription()
        performPriceSubscription()

        presenter?.didReceive(chainAsset: selectedChainAsset)
    }

    func remakeSubscriptions() {
        performAssetBalanceSubscription()
        performPriceSubscription()
    }
}

extension StakingSetupAmountInteractor: WalletLocalStorageSubscriber,
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
            presenter?.didReceive(assetBalance: balance)
        case let .failure(error):
            presenter?.didReceive(error: .assetBalance(error))
        }
    }
}

extension StakingSetupAmountInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        if selectedChainAsset.asset.priceId == priceId {
            switch result {
            case let .success(priceData):
                presenter?.didReceive(price: priceData)
            case let .failure(error):
                presenter?.didReceive(error: .price(error))
            }
        }
    }
}

extension StakingSetupAmountInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = selectedChainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
