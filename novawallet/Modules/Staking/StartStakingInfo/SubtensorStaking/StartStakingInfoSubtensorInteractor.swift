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
    let maxApyProvider: SubtensorMaxApyProviderProtocol
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol

    private let headlineCallStore = CancellableCallStore()
    private var boundWalletId: MetaAccountModel.Id?
    private var hasReportedAccountChange = false
    private var seed: HTTPCachePeek<Decimal?> = .miss

    init(
        state: SubtensorStakingSharedStateProtocol,
        maxApyProvider: SubtensorMaxApyProviderProtocol,
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
        self.maxApyProvider = maxApyProvider
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

        headlineCallStore.cancel()
    }

    override func setup() {
        super.setup()

        state.setup(for: selectedAccount)

        boundWalletId = selectedWalletSettings.value?.metaId
        eventCenter.add(observer: self, dispatchIn: .main)

        if !seed.isFresh {
            provideHeadline()
        }
    }
}

private extension StartStakingInfoSubtensorInteractor {
    func provideHeadline() {
        headlineCallStore.cancel()

        executeCancellable(
            wrapper: maxApyProvider.createMaxApyWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: headlineCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(maxApy):
                self?.presenter?.didReceive(headlineRate: maxApy)
            case let .failure(error):
                self?.logger.warning("Max APY fetch error: \(error)")
                self?.presenter?.didReceive(headlineRate: nil)
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

extension StartStakingInfoSubtensorInteractor: StartStakingInfoSubtensorInteractorInputProtocol {
    func cachedHeadlineRate() -> HTTPCachePeek<Decimal?> {
        seed = maxApyProvider.cachedMaxApy()

        return seed
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
