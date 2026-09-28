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
    let strategiesDataSource: SubtensorStakingStrategiesDataSourceProtocol
    let logger: LoggerProtocol

    private let networkInfoCancellableStore = CancellableCallStore()
    private let strategiesCancellableStore = CancellableCallStore()

    init(
        state: SubtensorStakingSharedStateProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol,
        networkInfoFactory: SubtensorNetworkInfoFactoryProtocol,
        strategiesDataSource: SubtensorStakingStrategiesDataSourceProtocol,
        currencyManager: CurrencyManagerProtocol,
        sharedOperation: SharedOperationProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.state = state
        self.networkInfoFactory = networkInfoFactory
        self.strategiesDataSource = strategiesDataSource
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
        strategiesCancellableStore.cancel()
    }

    override func setup() {
        super.setup()

        state.setup(for: selectedAccount)

        provideNetworkInfo()
        provideRootAnnualReturn()
        provideStrategies()
    }
}

// MARK: Private

private extension StartStakingInfoSubtensorInteractor {
    func provideNetworkInfo() {
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

    func provideRootAnnualReturn() {
        state.rewardCalculatorService.fetchEngine(runningCompletionIn: .main) { [weak self] result in
            switch result {
            case let .success(engine):
                // the take is per delegate and unknown before a delegate is picked, so the entry
                // screen shows the gross network-average rate (spec §6.2)
                self?.presenter?.didReceive(rootAnnualReturn: engine.rootAnnualReturn())
            case let .failure(error):
                // the tile degrades to its APY-less variant rather than showing a guess
                self?.logger.error("Root APY unavailable: \(error)")
                self?.presenter?.didReceive(rootAnnualReturn: nil)
            }
        }
    }

    func provideStrategies() {
        strategiesCancellableStore.cancel()

        executeCancellable(
            wrapper: strategiesDataSource.fetchStrategies(),
            inOperationQueue: operationQueue,
            backingCallIn: strategiesCancellableStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(strategies):
                self?.presenter?.didReceive(strategies: strategies)
            case let .failure(error):
                self?.presenter?.didReceiveStrategies(error: error)
            }
        }
    }
}

extension StartStakingInfoSubtensorInteractor: StartStakingInfoSubtensorInteractorInputProtocol {
    func retryStrategies() {
        provideStrategies()
    }
}
