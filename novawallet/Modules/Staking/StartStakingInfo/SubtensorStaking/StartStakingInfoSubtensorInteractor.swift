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
    let logger: LoggerProtocol

    private let headlineCallStore = CancellableCallStore()

    init(
        state: SubtensorStakingSharedStateProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        sharedOperation: SharedOperationProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.state = state
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

        headlineCallStore.cancel()
    }

    override func setup() {
        super.setup()

        state.setup(for: selectedAccount)

        provideHeadline()
    }
}

private extension StartStakingInfoSubtensorInteractor {
    func provideHeadline() {
        headlineCallStore.cancel()

        executeCancellable(
            wrapper: state.earnServices.earnConfigProvider.createConfigWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: headlineCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(config):
                self?.presenter?.didReceive(headlineRate: config.headlineMaxAnnualRate)
            case let .failure(error):
                self?.logger.error("Earn config request failed: \(error)")
                self?.presenter?.didReceive(headlineRate: nil)
            }
        }
    }
}

extension StartStakingInfoSubtensorInteractor: StartStakingInfoSubtensorInteractorInputProtocol {}
