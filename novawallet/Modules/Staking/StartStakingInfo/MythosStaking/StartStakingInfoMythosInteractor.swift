import Foundation
import Operation_iOS

final class StartStakingInfoMythosInteractor: StartStakingInfoBaseInteractor {
    var presenter: StartStakingInfoMythosInteractorOutputProtocol? {
        get {
            basePresenter as? StartStakingInfoMythosInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    var chainRegistry: ChainRegistryProtocol { state.chainRegistry }

    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol {
        state.generalLocalSubscriptionFactory
    }

    var stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol {
        state.stakingLocalSubscriptionFactory
    }

    var chain: ChainModel {
        state.stakingOption.chainAsset.chain
    }

    let state: MythosStakingSharedStateProtocol
    let durationOperationFactory: MythosStkDurationOperationFactoryProtocol
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol

    private let rewardCalculatorCancellableStore = CancellableCallStore()
    private let stakingDurationCancellableStore = CancellableCallStore()

    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    private var minStakeProvider: AnyDataProvider<DecodedBigUInt>?
    private var currentSessionProvider: AnyDataProvider<DecodedU32>?

    init(
        state: MythosStakingSharedStateProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol,
        durationOperationFactory: MythosStkDurationOperationFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        sharedOperation: SharedOperationProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.state = state
        self.durationOperationFactory = durationOperationFactory
        self.eventCenter = eventCenter
        self.logger = logger

        super.init(
            selectedWalletSettings: selectedWalletSettings,
            selectedChainAsset: state.stakingOption.chainAsset,
            selectedStakingType: state.stakingOption.type,
            sharedOperation: sharedOperation,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingDashboardProviderFactory: stakingDashboardProviderFactory,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }

    deinit {
        state.throttle()

        rewardCalculatorCancellableStore.cancel()
        stakingDurationCancellableStore.cancel()
    }

    private func performBlockNumberSubscription() {
        let chainId = selectedChainAsset.chain.chainId
        blockNumberProvider = subscribeToBlockNumber(for: chainId)
    }

    private func performMinStakeSubscription() {
        let chainId = selectedChainAsset.chain.chainId
        minStakeProvider = subscribeToMinStake(for: chainId)
    }

    private func performCurrentSessionSubscription() {
        let chainId = selectedChainAsset.chain.chainId
        currentSessionProvider = subscribeToCurrentSession(for: chainId)
    }

    private func provideStakingDuration() {
        stakingDurationCancellableStore.cancel()

        let wrapper = durationOperationFactory.createDurationOperation(
            for: chain.chainId,
            blockTimeEstimationService: state.blockTimeService
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: stakingDurationCancellableStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(duration):
                self?.presenter?.didReceive(duration: duration)
            case let .failure(error):
                self?.logger.error("Unexpected duration error: \(error)")
            }
        }
    }

    private func provideRewardCalculationEngine() {
        rewardCalculatorCancellableStore.cancel()

        let operation = state.rewardCalculatorService.fetchCalculatorOperation()

        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            backingCallIn: rewardCalculatorCancellableStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(engine):
                self?.presenter?.didReceive(calculator: engine)
            case let .failure(error):
                self?.logger.error("Unexpected duration error: \(error)")
            }
        }
    }

    override func setup() {
        super.setup()

        state.setup(for: selectedAccount?.chainAccount.accountId)
        eventCenter.add(observer: self, dispatchIn: .main)

        performMinStakeSubscription()
        performCurrentSessionSubscription()
        performBlockNumberSubscription()
        provideStakingDuration()
    }
}

extension StartStakingInfoMythosInteractor: StartStakingInfoMythosInteractorInputProtocol {}

extension StartStakingInfoMythosInteractor: EventVisitorProtocol {
    func processBlockTimeChanged(event: BlockTimeChanged) {
        guard chain.chainId == event.chainId else { return }

        provideStakingDuration()
    }

    func processStakingRewardsInfoChanged(event: StakingRewardInfoChanged) {
        guard chain.chainId == event.chainId else { return }

        logger.debug("Rewards calculator updated")

        provideRewardCalculationEngine()
    }
}

extension StartStakingInfoMythosInteractor: MythosStakingLocalStorageSubscriber, MythosStakingLocalStorageHandler {
    func handleMinStake(
        result: Result<Balance?, Error>,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(minStake):
            if let minStake {
                presenter?.didReceive(minStake: minStake)
            }
        case let .failure(error):
            logger.error("Min stake unexpected error: \(error)")
        }
    }

    func handleCurrentSession(
        result: Result<SessionIndex?, Error>,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(session):
            if let session {
                provideRewardCalculationEngine()

                presenter?.didReceive(currentSession: session)
            }
        case let .failure(error):
            logger.error("Current session unexpected error: \(error)")
        }
    }
}

extension StartStakingInfoMythosInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId: ChainModel.Id
    ) {
        guard selectedChainAsset.chain.chainId == chainId else {
            return
        }

        switch result {
        case let .success(blockNumber):
            presenter?.didReceive(blockNumber: blockNumber)
        case let .failure(error):
            logger.error("Block number unexpected error: \(error)")
        }
    }
}
