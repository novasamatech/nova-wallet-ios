import RobinHood
import Foundation

final class StartStakingParachainInteractor: StartStakingInfoInteractor, AnyCancellableCleaning {
    let chainRegistry: ChainRegistryProtocol
    let stateFactory: ParachainStakingStateFactoryProtocol
    private var sharedState: ParachainStakingSharedState?

    let networkInfoFactory: ParaStkNetworkInfoOperationFactoryProtocol
    let eventCenter: EventCenterProtocol

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
        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

extension StartStakingParachainInteractor: EventVisitorProtocol {
    func processEraStakersInfoChanged(event _: EraStakersInfoChanged) {
        provideNetworkInfo()
    }
}
