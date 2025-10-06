import Operation_iOS
import Foundation

final class StartStakingParachainInteractor: StartStakingInfoBaseInteractor, AnyCancellableCleaning,
    RuntimeConstantFetching {
    var chainRegistry: ChainRegistryProtocol { state.chainRegistry }

    let state: ParachainStakingSharedStateProtocol
    let networkInfoFactory: ParaStkNetworkInfoOperationFactoryProtocol
    let eventCenter: EventCenterProtocol
    let durationOperationFactory: ParaStkDurationOperationFactoryProtocol

    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol {
        state.generalLocalSubscriptionFactory
    }

    var stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol {
        state.stakingLocalSubscriptionFactory
    }

    private var roundInfoProvider: AnyDataProvider<ParachainStaking.DecodedRoundInfo>?
    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    private var networkInfoCancellable: CancellableCall?
    private var rewardCalculatorCancellable: CancellableCall?
    private var durationCancellable: CancellableCall?
    private var rewardPaymentDelayCancellable: CancellableCall?

    weak var presenter: StartStakingInfoParachainInteractorOutputProtocol? {
        didSet {
            basePresenter = presenter
        }
    }

    init(
        state: ParachainStakingSharedStateProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        networkInfoFactory: ParaStkNetworkInfoOperationFactoryProtocol,
        durationOperationFactory: ParaStkDurationOperationFactoryProtocol,
        sharedOperation: SharedOperationProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol
    ) {
        self.state = state
        self.networkInfoFactory = networkInfoFactory
        self.eventCenter = eventCenter
        self.durationOperationFactory = durationOperationFactory

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

        clear(cancellable: &networkInfoCancellable)
        clear(cancellable: &rewardCalculatorCancellable)
        clear(cancellable: &durationCancellable)
        clear(cancellable: &rewardPaymentDelayCancellable)
    }

    private func provideNetworkInfo() {
        clear(cancellable: &networkInfoCancellable)
        let chainId = selectedChainAsset.chain.chainId

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter?.didReceive(error: .networkInfo(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        let collatorService = state.collatorService
        let rewardService = state.rewardCalculationService

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

        let calculatorService = state.rewardCalculationService

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

        let blockTimeService = state.blockTimeService

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
            operationQueue: operationQueue
        ) { [weak self] (result: Result<UInt32, Error>) in
            DispatchQueue.main.async {
                switch result {
                case let .success(value):
                    self?.presenter?.didReceive(rewardPaymentDelay: value)
                case let .failure(error):
                    self?.presenter?.didReceive(error: .rewardPaymentDelay(error))
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

    override func setup() {
        super.setup()

        state.setup(for: selectedAccount?.chainAccount.accountId)
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

    func processBlockTimeChanged(event _: BlockTimeChanged) {
        provideStakingDurationInfo()
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
