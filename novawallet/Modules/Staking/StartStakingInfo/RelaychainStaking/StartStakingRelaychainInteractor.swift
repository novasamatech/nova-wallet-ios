import RobinHood
import BigInt
import Foundation
import SubstrateSdk

final class StartStakingRelaychainInteractor: StartStakingInfoBaseInteractor, AnyCancellableCleaning {
    let state: RelaychainStakingSharedStateProtocol

    var chainRegistry: ChainRegistryProtocol { state.chainRegistry }

    var stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol {
        state.localSubscriptionFactory
    }

    private var minNominatorBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var bagListSizeProvider: AnyDataProvider<DecodedU32>?
    private var eraCompletionTimeCancellable: CancellableCall?
    private var networkInfoCancellable: CancellableCall?
    private var rewardCalculatorCancellable: CancellableCall?

    weak var presenter: StartStakingInfoRelaychainInteractorOutputProtocol? {
        didSet {
            basePresenter = presenter
        }
    }

    init(
        selectedWalletSettings: SelectedWalletSettings,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        state: RelaychainStakingSharedStateProtocol,
        operationQueue: OperationQueue
    ) {
        self.state = state

        super.init(
            selectedWalletSettings: selectedWalletSettings,
            selectedChainAsset: state.stakingOption.chainAsset,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingAssetSubscriptionService: state.globalRemoteSubscriptionService,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }

    deinit {
        state.throttle()

        clear(cancellable: &networkInfoCancellable)
        clear(dataProvider: &minNominatorBondProvider)
        clear(dataProvider: &bagListSizeProvider)
        clear(cancellable: &eraCompletionTimeCancellable)
        clear(cancellable: &rewardCalculatorCancellable)
    }

    private func provideNetworkStakingInfo() {
        clear(cancellable: &networkInfoCancellable)

        let chain = selectedChainAsset.chain
        let networkInfoFactory = state.createNetworkInfoOperationFactory()
        let chainId = chain.chainId

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter?.didReceive(error: .networkStakingInfo(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        let eraValidatorService = state.eraValidatorService

        let wrapper = networkInfoFactory.networkStakingOperation(
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
                    self?.presenter?.didReceive(networkInfo: info)
                } catch {
                    self?.presenter?.didReceive(error: .networkStakingInfo(error))
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

        let chainId = selectedChainAsset.chain.chainId

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter?.didReceive(error: .eraCountdown(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            presenter?.didReceive(error: .eraCountdown(ChainRegistryError.connectionUnavailable))
            return
        }

        let eraCountdownOperationFactory = state.createEraCountdownOperationFactory()

        let operationWrapper = eraCountdownOperationFactory.fetchCountdownOperationWrapper(
            for: connection,
            runtimeService: runtimeService
        )

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

        let calculatorService = state.rewardCalculatorService

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

        provideRewardCalculator()
        provideNetworkStakingInfo()
        performMinNominatorBondSubscription()
        performBagListSizeSubscription()
        provideEraCompletionTime()
    }
}

extension StartStakingRelaychainInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(bond):
            presenter?.didReceive(minNominatorBond: bond)
        case let .failure(error):
            presenter?.didReceive(error: .minNominatorBond(error))
        }
    }

    func handleBagListSize(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(size):
            presenter?.didReceive(bagListSize: size)
        case let .failure(error):
            presenter?.didReceive(error: .bagListSize(error))
        }
    }
}

extension StartStakingRelaychainInteractor: StartStakingInfoRelaychainInteractorInputProtocol {
    func retryNetworkStakingInfo() {
        provideNetworkStakingInfo()
    }

    func remakeMinNominatorBondSubscription() {
        performMinNominatorBondSubscription()
    }

    func remakeBagListSizeSubscription() {
        performBagListSizeSubscription()
    }

    func retryEraCompletionTime() {
        provideEraCompletionTime()
    }

    func remakeCalculator() {
        provideRewardCalculator()
    }
}
