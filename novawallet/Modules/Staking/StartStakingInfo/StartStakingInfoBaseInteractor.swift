import UIKit
import RobinHood
import BigInt

class StartStakingInfoBaseInteractor: StartStakingInfoInteractorInputProtocol, AnyProviderAutoCleaning {
    weak var basePresenter: StartStakingInfoInteractorOutputProtocol?
    let selectedChainAsset: ChainAsset
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let selectedWalletSettings: SelectedWalletSettings
    let stakingAssetSubscriptionService: StakingRemoteSubscriptionServiceProtocol

    private(set) var priceProvider: StreamableProvider<PriceData>?
    private(set) var balanceProvider: StreamableProvider<AssetBalance>?
    private(set) var selectedAccount: MetaChainAccountResponse?
    private(set) var operationQueue: OperationQueue
    private(set) var chainSubscriptionId: UUID?

    init(
        selectedWalletSettings: SelectedWalletSettings,
        selectedChainAsset: ChainAsset,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingAssetSubscriptionService: StakingRemoteSubscriptionServiceProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.selectedChainAsset = selectedChainAsset
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.stakingAssetSubscriptionService = stakingAssetSubscriptionService
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    deinit {
        clear(streamableProvider: &priceProvider)
        clear(streamableProvider: &balanceProvider)
        clearChainRemoteSubscription()
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

    private func clearChainRemoteSubscription() {
        let chainId = selectedChainAsset.chain.chainId

        if let chainSubscriptionId = chainSubscriptionId {
            stakingAssetSubscriptionService.detachFromGlobalData(
                for: chainSubscriptionId,
                chainId: chainId,
                queue: nil,
                closure: nil
            )

            self.chainSubscriptionId = nil
        }
    }

    private func setupChainRemoteSubscription() {
        let chainId = selectedChainAsset.chain.chainId

        chainSubscriptionId = stakingAssetSubscriptionService.attachToGlobalData(
            for: chainId,
            queue: nil,
            closure: nil
        )
    }

    func setup() {
        setupSelectedAccount()
        setupChainRemoteSubscription()

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
