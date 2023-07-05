import UIKit
import RobinHood
import BigInt

class StartStakingInfoInteractor: StartStakingInfoInteractorInputProtocol {
    weak var presenter: StartStakingInfoInteractorOutputProtocol?
    let selectedChainAsset: ChainAsset
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let selectedWalletSettings: SelectedWalletSettings

    private(set) var priceProvider: StreamableProvider<PriceData>?
    private(set) var balanceProvider: StreamableProvider<AssetBalance>?
    private(set) var selectedAccount: MetaChainAccountResponse?
    private(set) var operationQueue: OperationQueue
    private(set) var observableBalance: Observable<AssetBalance?> = .init(state: nil)

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
        guard let priceId = selectedChainAsset.asset.priceId else {
            presenter?.didReceivePrice(nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    private func performAssetBalanceSubscription() {
        let chainAssetId = selectedChainAsset.chainAssetId

        guard let accountId = selectedAccount?.chainAccount.accountId else {
            presenter?.didReceiveAssetBalance(nil)
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

        presenter?.didReceiveAccount(selectedAccount)
    }

    func setup() {
        setupSelectedAccount()
        performAssetBalanceSubscription()
        performPriceSubscription()

        presenter?.didReceiveChainAsset(selectedChainAsset)
    }
}

extension StartStakingInfoInteractor: WalletLocalStorageSubscriber,
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
            observableBalance.state = balance ?? .createZero(
                for: .init(chainId: chainId, assetId: assetId),
                accountId: accountId
            )
            presenter?.didReceiveAssetBalance(balance)
        case let .failure(error):
            presenter?.didReceiveError(.assetBalance(error))
        }
    }
}

extension StartStakingInfoInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        if selectedChainAsset.asset.priceId == priceId {
            switch result {
            case let .success(priceData):
                presenter?.didReceivePrice(priceData)
            case let .failure(error):
                presenter?.didReceiveError(.price(error))
            }
        }
    }
}

extension StartStakingInfoInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = selectedChainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
