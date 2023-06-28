import RobinHood
import BigInt
import Foundation
import SubstrateSdk

final class StartStakingRelaychainInteractor: StartStakingInfoInteractor, AnyCancellableCleaning {
    private var networkInfoCancellable: CancellableCall?
    private var sharedState: StakingSharedState?
    let chainRegistry: ChainRegistryProtocol
    let stateFactory: RelaychainStakingStateFactoryProtocol

    var stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol

    private var minNominatorBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var bagListSizeProvider: AnyDataProvider<DecodedU32>?
    private var eraCompletionTimeCancellable: CancellableCall?

    init(
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        stateFactory: RelaychainStakingStateFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.stateFactory = stateFactory
        self.chainRegistry = chainRegistry
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory

        super.init(
            selectedWalletSettings: selectedWalletSettings,
            selectedChainAsset: chainAsset,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }

    private func provideNetworkStakingInfo() {
        do {
            clear(cancellable: &networkInfoCancellable)

            guard let sharedState = sharedState else {
                return
            }
            let chain = selectedChainAsset.chain
            let networkInfoFactory = try sharedState.createNetworkInfoOperationFactory(for: chain)
            let chainId = chain.chainId

            guard
                let runtimeService = chainRegistry.getRuntimeProvider(for: chainId),
                let eraValidatorService = sharedState.eraValidatorService else {
                presenter?.didReceiveError(.networkStakingInfo(ChainRegistryError.runtimeMetadaUnavailable))
                return
            }

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
                        self?.minStakeCalculator.networkInfo = info
                        //  self?.presenter?.didReceive(networkStakingInfo: info)
                    } catch {
                        self?.presenter?.didReceiveError(.networkStakingInfo(error))
                    }
                }
            }

            networkInfoCancellable = wrapper

            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        } catch {
            presenter?.didReceiveError(.networkStakingInfo(error))
        }
    }

    func performMinNominatorBondSubscription() {
        minNominatorBondProvider = subscribeToMinNominatorBond(for: selectedChainAsset.chain.chainId)
    }

    func performBagListSizeSubscription() {
        bagListSizeProvider = subscribeBagsListSize(for: selectedChainAsset.chain.chainId)
    }

    private var minStakeCalculator = MinStakeCalculator() {
        didSet {
            if let minStake = minStakeCalculator.calculate() {
                presenter?.didReceiveMinStake(minStake)
            }
        }
    }

    private func setupState() {
        do {
            let state = try stateFactory.createState()
            sharedState = state
            sharedState?.setupServices()
        } catch {
            presenter?.didReceiveError(.createState(error))
        }
    }

    private func provideEraCompletionTime() {
        do {
            clear(cancellable: &eraCompletionTimeCancellable)
            guard let sharedState = sharedState else {
                return
            }

            let chainId = selectedChainAsset.chain.chainId

            guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
                presenter?.didReceiveError(.stakeTime(ChainRegistryError.runtimeMetadaUnavailable))
                return
            }

            guard let connection = chainRegistry.getConnection(for: chainId) else {
                presenter?.didReceiveError(.stakeTime(ChainRegistryError.connectionUnavailable))
                return
            }

            let storageRequestFactory = StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: OperationManager(operationQueue: operationQueue)
            )

            let eraCountdownOperationFactory = try sharedState.createEraCountdownOperationFactory(
                for: selectedChainAsset.chain,
                storageRequestFactory: storageRequestFactory
            )

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
                        self?.presenter?.didReceiveEraTime(result.eraTimeInterval)
                    } catch {
                        self?.presenter?.didReceiveError(.stakeTime(error))
                    }
                }
            }

            eraCompletionTimeCancellable = operationWrapper

            operationQueue.addOperations(operationWrapper.allOperations, waitUntilFinished: false)
        } catch {
            presenter?.didReceiveError(.stakeTime(error))
        }
    }

    override func setup() {
        super.setup()

        setupState()
        provideNetworkStakingInfo()
        performMinNominatorBondSubscription()
        performBagListSizeSubscription()
        provideEraCompletionTime()
    }
}

extension StartStakingRelaychainInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case .success:
            minStakeCalculator.minNominatorBondResult = result
        case let .failure(error):
            presenter?.didReceiveError(.minStake(error))
        }
    }

    func handleBagListSize(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case .success:
            minStakeCalculator.bagListSizeResult = result
        case let .failure(error):
            presenter?.didReceiveError(.minStake(error))
        }
    }
}
