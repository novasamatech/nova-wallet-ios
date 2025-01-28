import UIKit
import Operation_iOS
import SubstrateSdk
import SoraFoundation

final class MythosStakingDetailsInteractor: AnyProviderAutoCleaning {
    weak var presenter: MythosStakingDetailsInteractorOutputProtocol?

    var chainRegistry: ChainRegistryProtocol {
        sharedState.chainRegistry
    }

    let selectedAccount: MetaChainAccountResponse
    let sharedState: MythosStakingSharedStateProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let eventCenter: EventCenterProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var frozenBalanceStore: MythosStakingFrozenBalanceStore?

    var priceProvider: StreamableProvider<PriceData>?
    var balanceProvider: StreamableProvider<AssetBalance>?

    var chain: ChainModel {
        chainAsset.chain
    }

    var chainAsset: ChainAsset {
        sharedState.stakingOption.chainAsset
    }

    var selectedAccountId: AccountId {
        selectedAccount.chainAccount.accountId
    }

    init(
        selectedAccount: MetaChainAccountResponse,
        sharedState: MythosStakingSharedStateProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        eventCenter: EventCenterProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.sharedState = sharedState
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.eventCenter = eventCenter
        self.applicationHandler = applicationHandler
        self.operationQueue = operationQueue
        self.logger = logger
        self.currencyManager = currencyManager
    }

    deinit {
        sharedState.throttle()
    }
}

extension MythosStakingDetailsInteractor {
    func setupState() {
        sharedState.setup(for: selectedAccountId)

        presenter?.didReceiveChainAsset(chainAsset)
        presenter?.didReceiveAccount(selectedAccount)
    }

    func makeBalanceSubscription() {
        clear(streamableProvider: &balanceProvider)
        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccountId,
            chainId: chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    func makePriceSubscription() {
        clear(streamableProvider: &priceProvider)

        guard let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    func makeStakingDetailsSubscription() {
        sharedState.detailsSyncService?.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            self?.presenter?.didReceiveStakingDetails(newState)
        }
    }

    func makeClaimableRewardsSubscription() {
        sharedState.claimableRewardsService?.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            self?.presenter?.didReceiveClaimableRewards(newState)
        }
    }

    func setupFrozenStore() {
        if frozenBalanceStore == nil {
            frozenBalanceStore = MythosStakingFrozenBalanceStore(
                accountId: selectedAccountId,
                chainAssetId: chainAsset.chainAssetId,
                walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
                logger: logger
            )

            frozenBalanceStore?.setup()
        }

        frozenBalanceStore?.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            self?.presenter?.didReceiveFrozenBalance(newState)
        }
    }

    func provideElectedCollators() {
        let operation = sharedState.collatorService.fetchInfoOperation()

        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(collators):
                self?.presenter?.didReceiveElectedCollators(collators)
            case let .failure(error):
                self?.logger.error("Elected collators fetch failed: \(error)")
            }
        }
    }

    func provideRewardsCalculator() {
        let operation = sharedState.rewardCalculatorService.fetchCalculatorOperation()

        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(calculator):
                self?.presenter?.didReceiveRewardCalculator(calculator)
            case let .failure(error):
                self?.logger.error("Rewards service fetch failed: \(error)")
            }
        }
    }
}

extension MythosStakingDetailsInteractor: MythosStakingDetailsInteractorInputProtocol {
    func setup() {
        setupState()

        makeBalanceSubscription()
        makePriceSubscription()
        setupFrozenStore()
        makeStakingDetailsSubscription()
        makeClaimableRewardsSubscription()

        provideRewardsCalculator()
        provideElectedCollators()

        eventCenter.add(observer: self, dispatchIn: .main)

        applicationHandler.delegate = self
    }
}

extension MythosStakingDetailsInteractor: WalletLocalStorageSubscriber,
    WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard
            chainId == chain.chainId,
            assetId == chainAsset.asset.assetId,
            accountId == selectedAccountId else {
            return
        }

        switch result {
        case let .success(balance):
            presenter?.didReceiveAssetBalance(balance)
        case let .failure(error):
            logger.error("Balance subscription error: \(error)")
        }
    }
}

extension MythosStakingDetailsInteractor: EventVisitorProtocol {
    func processEraStakersInfoChanged(event: EraStakersInfoChanged) {
        guard event.chainId == chain.chainId else {
            return
        }

        provideElectedCollators()
        provideRewardsCalculator()
    }
}

extension MythosStakingDetailsInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        priceProvider?.refresh()
    }
}

extension MythosStakingDetailsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        if chainAsset.asset.priceId == priceId {
            switch result {
            case let .success(priceData):
                presenter?.didReceivePrice(priceData)
            case let .failure(error):
                logger.error("Price subscription error: \(error)")
            }
        }
    }
}

extension MythosStakingDetailsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        makePriceSubscription()
    }
}
