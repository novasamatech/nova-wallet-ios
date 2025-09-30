import Operation_iOS
import BigInt
import Foundation
import SubstrateSdk

final class StartStakingRelaychainInteractor: StartStakingInfoBaseInteractor, AnyCancellableCleaning {
    let state: RelaychainStartStakingStateProtocol
    let chainRegistry: ChainRegistryProtocol
    let networkInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol
    let eraCoundownOperationFactory: EraCountdownOperationFactoryProtocol
    let eventCenter: EventCenterProtocol

    var stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol {
        state.relaychainLocalSubscriptionFactory
    }

    var npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol {
        state.npLocalSubscriptionFactory
    }

    private var minNominatorBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var bagListSizeProvider: AnyDataProvider<DecodedU32>?
    private var minJoinBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var eraCompletionTimeCancellable: CancellableCall?
    private var networkInfoCancellable: CancellableCall?
    private var rewardCalculatorCancellable: CancellableCall?
    private var directStakingMinStakeBuilder: DirectStakingMinStakeBuilder?

    weak var presenter: StartStakingInfoRelaychainInteractorOutputProtocol? {
        didSet {
            basePresenter = presenter
        }
    }

    init(
        state: RelaychainStartStakingStateProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        networkInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol,
        eraCoundownOperationFactory: EraCountdownOperationFactoryProtocol,
        sharedOperation: SharedOperationProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.state = state
        self.chainRegistry = chainRegistry
        self.networkInfoOperationFactory = networkInfoOperationFactory
        self.eraCoundownOperationFactory = eraCoundownOperationFactory
        self.eventCenter = eventCenter

        super.init(
            selectedWalletSettings: selectedWalletSettings,
            selectedChainAsset: state.chainAsset,
            selectedStakingType: state.stakingType,
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
        clear(cancellable: &eraCompletionTimeCancellable)
        clear(cancellable: &rewardCalculatorCancellable)
    }

    private func provideNetworkStakingInfo() {
        clear(cancellable: &networkInfoCancellable)

        let chain = selectedChainAsset.chain
        let chainId = chain.chainId

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter?.didReceive(error: .directStakingMinStake(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        let eraValidatorService = state.eraValidatorService

        let wrapper = networkInfoOperationFactory.networkStakingOperation(
            for: eraValidatorService,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.networkInfoCancellable === wrapper else {
                    return
                }

                self?.networkInfoCancellable = nil

                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.directStakingMinStakeBuilder?.apply(param1: info)
                    self?.presenter?.didReceive(networkInfo: info)
                } catch {
                    self?.presenter?.didReceive(error: .directStakingMinStake(error))
                }
            }
        }

        networkInfoCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func performMinNominatorBondSubscription() {
        clear(dataProvider: &minNominatorBondProvider)
        minNominatorBondProvider = subscribeToMinNominatorBond(for: selectedChainAsset.chain.chainId)
    }

    private func performMinJoinBondSubscription() {
        clear(dataProvider: &minJoinBondProvider)

        if state.supportsPoolStaking() {
            minJoinBondProvider = subscribeMinJoinBond(for: selectedChainAsset.chain.chainId)
        } else {
            presenter?.didReceive(nominationPoolMinStake: nil)
        }
    }

    private func performBagListSizeSubscription() {
        clear(dataProvider: &bagListSizeProvider)
        bagListSizeProvider = subscribeBagsListSize(for: selectedChainAsset.chain.chainId)
    }

    private func setupState() {
        do {
            let account = SelectedWalletSettings.shared.value.fetch(for: selectedChainAsset.chain.accountRequest())
            try state.setup(for: account?.accountId)
        } catch {
            presenter?.didReceive(error: .createState(error))
        }
    }

    private func provideEraCompletionTime() {
        clear(cancellable: &eraCompletionTimeCancellable)

        let operationWrapper = eraCoundownOperationFactory.fetchCountdownOperationWrapper()

        operationWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.eraCompletionTimeCancellable === operationWrapper else {
                    return
                }

                self?.eraCompletionTimeCancellable = nil

                do {
                    let result = try operationWrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(eraCountdown: result)
                } catch {
                    self?.presenter?.didReceive(error: .eraCountdown(error))
                }
            }
        }

        eraCompletionTimeCancellable = operationWrapper

        operationQueue.addOperations(operationWrapper.allOperations, waitUntilFinished: false)
    }

    private func provideRewardCalculator() {
        clear(cancellable: &rewardCalculatorCancellable)

        let calculatorService = state.relaychainRewardCalculatorService

        let operation = calculatorService.fetchCalculatorOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.rewardCalculatorCancellable === operation else {
                    return
                }
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

    override func setup() {
        super.setup()

        setupState()

        directStakingMinStakeBuilder = DirectStakingMinStakeBuilder { [weak self] minStake in
            self?.presenter?.didReceive(directStakingMinStake: minStake)
        }

        provideRewardCalculator()
        provideNetworkStakingInfo()
        performMinNominatorBondSubscription()
        performBagListSizeSubscription()
        performMinJoinBondSubscription()
        provideEraCompletionTime()

        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

extension StartStakingRelaychainInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(bond):
            directStakingMinStakeBuilder?.apply(param3: bond)
        case let .failure(error):
            presenter?.didReceive(error: .directStakingMinStake(error))
        }
    }

    func handleBagListSize(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(size):
            directStakingMinStakeBuilder?.apply(param2: size)
        case let .failure(error):
            presenter?.didReceive(error: .directStakingMinStake(error))
        }
    }
}

extension StartStakingRelaychainInteractor: NPoolsLocalStorageSubscriber, NPoolsLocalSubscriptionHandler {
    func handleMinJoinBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(minJoinBond):
            presenter?.didReceive(nominationPoolMinStake: minJoinBond)
        case let .failure(error):
            presenter?.didReceive(error: .nominationPoolsMinStake(error))
        }
    }
}

extension StartStakingRelaychainInteractor: StartStakingInfoRelaychainInteractorInputProtocol {
    func retryDirectStakingMinStake() {
        provideNetworkStakingInfo()
        performMinNominatorBondSubscription()
        performBagListSizeSubscription()
    }

    func retryEraCompletionTime() {
        provideEraCompletionTime()
    }

    func remakeCalculator() {
        provideRewardCalculator()
    }

    func retryNominationPoolsMinStake() {
        performMinJoinBondSubscription()
    }
}

extension StartStakingRelaychainInteractor: EventVisitorProtocol {
    func processEraStakersInfoChanged(event _: EraStakersInfoChanged) {
        provideNetworkStakingInfo()
    }

    func processBlockTimeChanged(event _: BlockTimeChanged) {
        provideNetworkStakingInfo()
        provideEraCompletionTime()
    }
}
