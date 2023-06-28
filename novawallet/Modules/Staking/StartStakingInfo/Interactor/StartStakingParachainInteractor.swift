import RobinHood
import Foundation

final class StartStakingParachainInteractor: StartStakingInfoInteractor, AnyCancellableCleaning {
    let chainRegistry: ChainRegistryProtocol
    let stateFactory: ParachainStakingStateFactoryProtocol
    private var sharedState: ParachainStakingSharedState?

    let networkInfoFactory: ParaStkNetworkInfoOperationFactoryProtocol
    let eventCenter: EventCenterProtocol
    var stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    private var roundInfoProvider: AnyDataProvider<ParachainStaking.DecodedRoundInfo>?
    private var networkInfoCancellable: CancellableCall?

    private var networkInfo: ParachainStaking.NetworkInfo? {
        didSet {
            if let networkInfo = networkInfo {
                let minStake = max(networkInfo.minStakeForRewards, networkInfo.minTechStake)
                presenter?.didReceiveMinStake(minStake)
            }
        }
    }

    init(
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        stateFactory: ParachainStakingStateFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        networkInfoFactory: ParaStkNetworkInfoOperationFactoryProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol
    ) {
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.stateFactory = stateFactory
        self.chainRegistry = chainRegistry
        self.networkInfoFactory = networkInfoFactory
        self.eventCenter = eventCenter

        super.init(
            selectedWalletSettings: selectedWalletSettings,
            selectedChainAsset: chainAsset,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }

    private func provideNetworkInfo() {
        clear(cancellable: &networkInfoCancellable)
        let chainId = selectedChainAsset.chain.chainId

        guard
            let sharedState = sharedState,
            let collatorService = sharedState.collatorService,
            let rewardService = sharedState.rewardCalculationService,
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter?.didReceiveError(.minStake(ChainRegistryError.runtimeMetadaUnavailable))
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

                self?.networkInfoCancellable = nil

                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.networkInfo = info
                } catch {
                    self?.presenter?.didReceiveError(.minStake(error))
                }
            }
        }

        networkInfoCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func performRoundInfoSubscription() {
        let chainId = selectedChainAsset.chain.chainId
        roundInfoProvider = subscribeToRound(for: chainId)
    }

    private func setupState() {
        do {
            sharedState = try stateFactory.createState()
            sharedState?.setupServices()
        } catch {
            presenter?.didReceiveError(.createState(error))
        }
    }

    override func setup() {
        super.setup()

        setupState()
        provideNetworkInfo()
        performRoundInfoSubscription()
        eventCenter.add(observer: self, dispatchIn: .main)
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
            break
        case let .failure(error):
            break
        }
    }
}
