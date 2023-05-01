import Foundation
import RobinHood
import SubstrateSdk
import SoraFoundation

final class ReferendumsInteractor: BaseReferendumsInteractor {
    weak var presenter: ReferendumsInteractorOutputProtocol? {
        didSet {
            basePresenter = presenter
        }
    }

    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    private(set) var priceProvider: StreamableProvider<PriceData>?
    private(set) var assetBalanceProvider: StreamableProvider<AssetBalance>?

    var unlockScheduleCancellable: CancellableCall?

    init(
        selectedMetaAccount: MetaAccountModel,
        governanceState: GovernanceSharedState,
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        serviceFactory: GovernanceServiceFactoryProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory

        super.init(
            selectedMetaAccount: selectedMetaAccount,
            governanceState: governanceState,
            chainRegistry: chainRegistry,
            serviceFactory: serviceFactory,
            applicationHandler: applicationHandler,
            operationQueue: operationQueue
        )

        self.currencyManager = currencyManager
    }

    deinit {
        clearCancellable()
    }

    override func clear() {
        clear(streamableProvider: &assetBalanceProvider)
        clear(streamableProvider: &priceProvider)
        clearSubscriptionFactory()
        clearCancellable()

        super.clear()
    }

    override func clearCancellable() {
        clear(cancellable: &unlockScheduleCancellable)

        super.clearCancellable()
    }

    private func clearSubscriptionFactory() {
        governanceState.replaceGovernanceFactory(for: nil)
    }

    override func setup(with accountId: AccountId?, option: GovernanceSelectedOption) {
        presenter?.didReceiveSelectedOption(option)
        provideDelegationsSupport(for: option)

        if let accountId = accountId {
            subscribeToAssetBalance(for: accountId, chain: option.chain)
        } else {
            presenter?.didReceiveAssetBalance(nil)
        }

        subscribeToAssetPrice(for: option.chain)
        setupSubscriptionFactory(for: option)
        super.setup(with: accountId, option: option)
    }

    private func setupSubscriptionFactory(for option: GovernanceSelectedOption) {
        governanceState.replaceGovernanceFactory(for: option)
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

    func subscribeToAssetPrice(for chain: ChainModel) {
        guard let priceId = chain.utilityAsset()?.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    func handleOptionChange(for newOption: GovernanceSelectedOption) {
        clear()

        let chain = newOption.chain
        let accountResponse = selectedMetaAccount.fetch(for: chain.accountRequest())

        setup(with: accountResponse?.accountId, option: newOption)
    }

    func provideDelegationsSupport(for newOption: GovernanceSelectedOption) {
        presenter?.didReceiveSupportDelegations(governanceState.supportsDelegations(for: newOption))
    }
}
