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

    let state: SubtensorSharedStateProtocol
    let maxApyOperationFactory: SubtensorMaxApyOperationFactoryProtocol
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol

    private let maxApyCallStore = CancellableCallStore()
    private var boundWalletId: MetaAccountModel.Id?
    private var hasReportedAccountChange = false

    init(
        state: SubtensorSharedStateProtocol,
        maxApyOperationFactory: SubtensorMaxApyOperationFactoryProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol,
        announcementsRepository: AnnouncementsRepositoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        sharedOperation: SharedOperationProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.state = state
        self.maxApyOperationFactory = maxApyOperationFactory
        self.eventCenter = eventCenter
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
            operationQueue: operationQueue,
            announcementsRepository: announcementsRepository
        )
    }

    deinit {
        state.throttle()

        maxApyCallStore.cancel()
    }

    override func setup() {
        super.setup()

        state.setup(for: selectedAccount)

        boundWalletId = selectedWalletSettings.value?.metaId
        eventCenter.add(observer: self, dispatchIn: .main)

        provideMaxApy()
    }
}

extension StartStakingInfoSubtensorInteractor: StartStakingInfoSubtensorInteractorInputProtocol {
    func retryMaxApy() {
        provideMaxApy()
    }
}

private extension StartStakingInfoSubtensorInteractor {
    func provideMaxApy() {
        maxApyCallStore.cancel()

        executeCancellable(
            wrapper: maxApyOperationFactory.createMaxApyWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: maxApyCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(rates):
                self?.eventCenter.notify(with: SubtensorMaxApyFetched())

                if let maxApy = rates.values.max() {
                    self?.presenter?.didReceive(maxApy: maxApy)
                } else {
                    self?.presenter?.didReceive(error: .maxApy(nil))
                }
            case let .failure(error):
                self?.logger.warning("Max APY fetch error: \(error)")
                self?.presenter?.didReceive(error: .maxApy(error))
            }
        }
    }

    func verifyBoundAccount() {
        guard !hasReportedAccountChange, !isBoundAccountSelected() else {
            return
        }

        hasReportedAccountChange = true
        presenter?.didReceiveAccountChange()
    }

    func isBoundAccountSelected() -> Bool {
        guard let wallet = selectedWalletSettings.value, wallet.metaId == boundWalletId else {
            return false
        }

        let accountId = wallet.fetchMetaChainAccount(
            for: selectedChainAsset.chain.accountRequest()
        )?.chainAccount.accountId

        return accountId == selectedAccount?.chainAccount.accountId
    }
}

extension StartStakingInfoSubtensorInteractor: EventVisitorProtocol {
    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {
        verifyBoundAccount()
    }

    func processWalletRemoved(event _: WalletRemoved) {
        verifyBoundAccount()
    }

    func processChainAccountChanged(event _: ChainAccountChanged) {
        verifyBoundAccount()
    }
}
