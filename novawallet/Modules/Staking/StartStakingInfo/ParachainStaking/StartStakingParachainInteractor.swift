import RobinHood
import Foundation

final class StartStakingParachainInteractor: StartStakingInfoBaseInteractor, AnyCancellableCleaning, RuntimeConstantFetching {
    let chainRegistry: ChainRegistryProtocol
    let stateFactory: ParachainStakingStateFactoryProtocol
    let networkInfoFactory: ParaStkNetworkInfoOperationFactoryProtocol
    let eventCenter: EventCenterProtocol
    let durationOperationFactory: ParaStkDurationOperationFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let stakingAccountSubscriptionService: ParachainStakingAccountSubscriptionServiceProtocol

    private var roundInfoProvider: AnyDataProvider<ParachainStaking.DecodedRoundInfo>?
    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    private var networkInfoCancellable: CancellableCall?
    private var rewardCalculatorCancellable: CancellableCall?
    private var durationCancellable: CancellableCall?
    private var rewardPaymentDelayCancellable: CancellableCall?
    private var sharedState: ParachainStakingSharedState?
    private var accountSubscriptionId: UUID?

    weak var presenter: StartStakingInfoParachainInteractorOutputProtocol? {
        didSet {
            basePresenter = presenter
        }
    }

    init(
        chainAsset: ChainAsset,
        selectedWalletSettings: SelectedWalletSettings,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingAssetSubscriptionService: StakingRemoteSubscriptionServiceProtocol,
        stakingAccountSubscriptionService: ParachainStakingAccountSubscriptionServiceProtocol,
        currencyManager: CurrencyManagerProtocol,
        stateFactory: ParachainStakingStateFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        networkInfoFactory: ParaStkNetworkInfoOperationFactoryProtocol,
        durationOperationFactory: ParaStkDurationOperationFactoryProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol
    ) {
        stakingLocalSubscriptionFactory = stateFactory.stakingLocalSubscriptionFactory
        generalLocalSubscriptionFactory = stateFactory.generalLocalSubscriptionFactory
        self.stateFactory = stateFactory
        self.chainRegistry = chainRegistry
        self.networkInfoFactory = networkInfoFactory
        self.eventCenter = eventCenter
        self.durationOperationFactory = durationOperationFactory
        self.stakingAccountSubscriptionService = stakingAccountSubscriptionService

        super.init(
            selectedWalletSettings: selectedWalletSettings,
            selectedChainAsset: chainAsset,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingAssetSubscriptionService: stakingAssetSubscriptionService,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }

    deinit {
        clear(cancellable: &networkInfoCancellable)
        clear(cancellable: &rewardCalculatorCancellable)
        clear(cancellable: &durationCancellable)
        clear(cancellable: &rewardPaymentDelayCancellable)
        clearAccountRemoteSubscription()
        sharedState?.throttleServices()
    }

    private func provideNetworkInfo() {
        clear(cancellable: &networkInfoCancellable)
        let chainId = selectedChainAsset.chain.chainId

        guard
            let sharedState = sharedState,
            let collatorService = sharedState.collatorService,
            let rewardService = sharedState.rewardCalculationService,
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter?.didReceive(error: .networkInfo(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        let wrapper = networkInfoFactory.networkStakingOperation(
            for: collatorService,
            rewardCalculatorService: rewardService,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.networkInfoCancellable === wrapper else {
                    return
                }

                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(networkInfo: info)
                } catch {
                    self?.presenter?.didReceive(error: .networkInfo(error))
                }

                self?.networkInfoCancellable = nil
            }
        }

        networkInfoCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func provideRewardCalculator() {
        clear(cancellable: &rewardCalculatorCancellable)

        guard let sharedState = sharedState, let calculatorService = sharedState.rewardCalculationService else {
            return
        }

        let operation = calculatorService.fetchCalculatorOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.rewardCalculatorCancellable === operation else {
                    return
                }

                self?.rewardCalculatorCancellable = nil

                do {
                    let engine = try operation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(calculator: engine)
                } catch {
                    self?.presenter?.didReceive(error: .calculator(error))
                }
            }
        }

        rewardCalculatorCancellable = operation

        operationQueue.addOperation(operation)
    }

    private func provideStakingDurationInfo() {
        clear(cancellable: &durationCancellable)

        guard let sharedState = sharedState, let blockTimeService = sharedState.blockTimeService else {
            return
        }

        let chainId = selectedChainAsset.chain.chainId

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter?.didReceive(error: .stakingDuration(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            presenter?.didReceive(error: .stakingDuration(ChainRegistryError.connectionUnavailable))
            return
        }

        let wrapper = durationOperationFactory.createDurationOperation(
            from: runtimeService,
            connection: connection,
            blockTimeEstimationService: blockTimeService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.durationCancellable === wrapper else {
                    return
                }

                self?.durationCancellable = nil

                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(stakingDuration: info)
                } catch {
                    self?.presenter?.didReceive(error: .stakingDuration(error))
                }
            }
        }

        durationCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func provideRewardPaymentDelay() {
        clear(cancellable: &rewardPaymentDelayCancellable)

        let chainId = selectedChainAsset.chain.chainId

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter?.didReceive(error: .rewardPaymentDelay(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        rewardPaymentDelayCancellable = fetchConstant(
            for: ParachainStaking.rewardPaymentDelay,
            runtimeCodingService: runtimeService,
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] (result: Result<UInt32, Error>) in
            DispatchQueue.main.async {
                switch result {
                case let .success(value):
                    self?.presenter?.didReceive(rewardPaymentDelay: value)
                case let .failure(error):
                    self?.presenter?.didReceive(error: .rewardPaymentDelay(ChainRegistryError.runtimeMetadaUnavailable))
                }
            }
        }
    }

    private func performRoundInfoSubscription() {
        let chainId = selectedChainAsset.chain.chainId
        roundInfoProvider = subscribeToRound(for: chainId)
    }

    private func performBlockNumberSubscription() {
        let chainId = selectedChainAsset.chain.chainId
        blockNumberProvider = subscribeToBlockNumber(for: chainId)
    }

    private func clearAccountRemoteSubscription() {
        let chainId = selectedChainAsset.chain.chainId

        if
            let accountSubscriptionId = accountSubscriptionId,
            let accountId = selectedAccount?.chainAccount.accountId {
            stakingAccountSubscriptionService.detachFromAccountData(
                for: accountSubscriptionId,
                chainId: chainId,
                accountId: accountId,
                queue: nil,
                closure: nil
            )

            self.accountSubscriptionId = nil
        }
    }

    private func setupAccountRemoteSubscription() {
        let chainId = selectedChainAsset.chain.chainId

        guard let accountId = selectedAccount?.chainAccount.accountId else {
            return
        }

        accountSubscriptionId = stakingAccountSubscriptionService.attachToAccountData(
            for: chainId,
            accountId: accountId,
            queue: nil,
            closure: nil
        )
    }

    private func setupState() {
        do {
            let state = try stateFactory.createState()
            sharedState = state
            sharedState?.setupServices()
        } catch {
            presenter?.didReceive(error: .createState(error))
        }
    }

    override func setup() {
        super.setup()

        setupAccountRemoteSubscription()
        setupState()
        eventCenter.add(observer: self, dispatchIn: .main)

        provideNetworkInfo()
        provideRewardCalculator()
        provideStakingDurationInfo()
        provideRewardPaymentDelay()
        performRoundInfoSubscription()
        performBlockNumberSubscription()
    }
}

extension StartStakingParachainInteractor: EventVisitorProtocol {
    func processEraStakersInfoChanged(event _: EraStakersInfoChanged) {
        provideNetworkInfo()
    }
}

extension StartStakingParachainInteractor: ParastakingLocalStorageSubscriber,
    ParastakingLocalStorageHandler {
    func handleParastakingRound(result: Result<ParachainStaking.RoundInfo?, Error>, for chainId: ChainModel.Id) {
        guard selectedChainAsset.chain.chainId == chainId else {
            return
        }

        switch result {
        case let .success(roundInfo):
            presenter?.didReceive(parastakingRound: roundInfo)
        case let .failure(error):
            presenter?.didReceive(error: .parastakingRound(error))
        }
    }
}

extension StartStakingParachainInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
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
            presenter?.didReceive(error: .blockNumber(error))
        }
    }
}

extension StartStakingParachainInteractor: StartStakingInfoParachainInteractorInputProtocol {
    func retryNetworkStakingInfo() {
        provideNetworkInfo()
    }

    func remakeCalculator() {
        provideRewardCalculator()
    }

    func retryStakingDuration() {
        provideStakingDurationInfo()
    }

    func retryRewardPaymentDelay() {
        provideRewardPaymentDelay()
    }
}
