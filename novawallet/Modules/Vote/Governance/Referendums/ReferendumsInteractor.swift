import Foundation
import RobinHood

final class ReferendumsInteractor: AnyProviderAutoCleaning {
    weak var presenter: ReferendumsInteractorOutputProtocol?

    let selectedMetaAccount: MetaAccountModel
    let governanceState: GovernanceSharedState
    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let currencyManager: CurrencyManagerProtocol

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var assetBalanceProvider: StreamableProvider<AssetBalance>?

    init(
        selectedMetaAccount: MetaAccountModel,
        governanceState: GovernanceSharedState,
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.governanceState = governanceState
        self.chainRegistry = chainRegistry
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.currencyManager = currencyManager
    }

    private func clear() {
        clear(streamableProvider: &assetBalanceProvider)
        clear(singleValueProvider: &priceProvider)
    }

    private func continueSetup() {
        guard let chain = governanceState.settings.value else {
            presenter?.didReceiveError(.settingsLoadFailed)
            return
        }

        let accountResponse = selectedMetaAccount.fetch(for: chain.accountRequest())

        setup(with: accountResponse?.accountId, chain: chain)
    }

    private func setup(with accountId: AccountId?, chain: ChainModel) {
        presenter?.didReceiveSelectedChain(chain)

        if let accountId = accountId {
            subscribeToAssetBalance(for: accountId, chain: chain)
        } else {
            presenter?.didReceiveAssetBalance(nil)
        }

        subscribeToAssetPrice(for: chain)
    }

    private func subscribeToAssetBalance(for accountId: AccountId, chain: ChainModel) {
        guard let asset = chain.utilityAsset() else {
            return
        }

        assetBalanceProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chain.chainId,
            assetId: asset.assetId
        )
    }

    private func subscribeToAssetPrice(for chain: ChainModel) {
        guard let priceId = chain.utilityAsset()?.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    private func handleChainChange(for newChain: ChainModel) {
        let accountResponse = selectedMetaAccount.fetch(for: newChain.accountRequest())

        setup(with: accountResponse?.accountId, chain: newChain)
    }
}

extension ReferendumsInteractor: ReferendumsInteractorInputProtocol {
    func setup() {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.governanceState.settings.setup(runningCompletionIn: .main) { result in
                switch result {
                case .success:
                    self?.continueSetup()
                case .failure:
                    self?.presenter?.didReceiveError(.settingsLoadFailed)
                }
            }
        }
    }

    func saveSelected(chainModel: ChainModel) {
        if chainModel.chainId != governanceState.settings.value?.chainId {
            clear()

            governanceState.settings.save(value: chainModel, runningCompletionIn: .main) { [weak self] result in
                switch result {
                case let .success(chain):
                    self?.handleChainChange(for: chain)
                case let .failure(error):
                    self?.presenter?.didReceiveError(.chainSaveFailed(error))
                }
            }
        }
    }
}

extension ReferendumsInteractor: WalletLocalSubscriptionHandler, WalletLocalStorageSubscriber {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            presenter?.didReceiveAssetBalance(balance)
        case let .failure(error):
            presenter?.didReceiveError(.balanceSubscriptionFailed(error))
        }
    }
}

extension ReferendumsInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(price):
            presenter?.didReceivePrice(price)
        case let .failure(error):
            presenter?.didReceiveError(.priceSubscriptionFailed(error))
        }
    }
}

extension ReferendumsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil, let chain = governanceState.settings.value {
            subscribeToAssetPrice(for: chain)
        }
    }
}
