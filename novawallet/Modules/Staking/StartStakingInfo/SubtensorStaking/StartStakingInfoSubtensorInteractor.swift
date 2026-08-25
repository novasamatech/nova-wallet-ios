import Foundation
import Operation_iOS

final class StartStakingInfoSubtensorInteractor: StartStakingInfoBaseInteractor {
    var presenter: StartStakingInfoSubtensorInteractorOutputProtocol? {
        get {
            basePresenter as? StartStakingInfoSubtensorInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let state: SubtensorStakingSharedStateProtocol
    let networkInfoFactory: SubtensorNetworkInfoFactoryProtocol
    let logger: LoggerProtocol

    private let networkInfoCancellableStore = CancellableCallStore()

    init(
        state: SubtensorStakingSharedStateProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol,
        networkInfoFactory: SubtensorNetworkInfoFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        sharedOperation: SharedOperationProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.state = state
        self.networkInfoFactory = networkInfoFactory
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

        networkInfoCancellableStore.cancel()
    }

    private func provideNetworkInfo() {
        networkInfoCancellableStore.cancel()

        let wrapper = networkInfoFactory.createNetworkInfoWrapper()

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: networkInfoCancellableStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(networkInfo):
                self?.presenter?.didReceive(networkInfo: networkInfo)
            case let .failure(error):
                self?.logger.error("Network info request failed: \(error)")
            }
        }
    }

    override func setup() {
        super.setup()

        state.setup(for: selectedAccount?.chainAccount.accountId)

        provideNetworkInfo()
    }
}

extension StartStakingInfoSubtensorInteractor: StartStakingInfoSubtensorInteractorInputProtocol {}
