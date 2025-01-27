import UIKit
import Operation_iOS
import SubstrateSdk

final class MythosStakingDetailsInteractor: AnyProviderAutoCleaning {
    weak var presenter: MythosStakingDetailsInteractorOutputProtocol?

    var chainRegistry: ChainRegistryProtocol {
        sharedState.chainRegistry
    }

    let selectedAccount: ChainAccountResponse
    let sharedState: MythosStakingSharedStateProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let eventCenter: EventCenterProtocol
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

    init(
        selectedAccount: ChainAccountResponse,
        sharedState: MythosStakingSharedStateProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        eventCenter: EventCenterProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.sharedState = sharedState
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.eventCenter = eventCenter
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
        sharedState.setup(for: selectedAccount.accountId)
    }

    func makeBalanceSubscription() {
        clear(streamableProvider: &balanceProvider)
        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
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

    func setupFrozenStore() {
        if frozenBalanceStore == nil {
            frozenBalanceStore = MythosStakingFrozenBalanceStore(
                accountId: selectedAccount.accountId,
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
            if let newState {
                self?.presenter?.didReceiveFrozenBalance(newState)
            }
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

    func providerRewardsCalculator() {
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
        makeStakingDetailsSubscription()
        setupFrozenStore()

        providerRewardsCalculator()
        provideElectedCollators()
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
            accountId == selectedAccount.accountId else {
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
