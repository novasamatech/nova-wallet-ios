import Foundation
import Operation_iOS

class SwipeGovInteractor: AnyProviderAutoCleaning {
    weak var presenter: SwipeGovInteractorOutputProtocol?

    private let metaAccount: MetaAccountModel
    private let governanceState: GovernanceSharedState
    private let sorting: ReferendumsSorting
    private let basketItemsRepository: AnyDataProviderRepository<VotingBasketItemLocal>
    private let operationQueue: OperationQueue

    private var basketItemsProvider: StreamableProvider<VotingBasketItemLocal>?
    private var votingPowerProvider: StreamableProvider<VotingPowerLocal>?
    private var assetBalanceProvider: StreamableProvider<AssetBalance>?

    private var modelBuilder: SwipeGovModelBuilderProtocol?

    private var observableState: ReferendumsObservableState {
        governanceState.observableState
    }

    private var chain: ChainModel {
        governanceState.settings.value.chain
    }

    let votingBasketSubscriptionFactory: VotingBasketLocalSubscriptionFactoryProtocol
    let votingPowerSubscriptionFactory: VotingPowerLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol

    let logger: LoggerProtocol

    init(
        metaAccount: MetaAccountModel,
        governanceState: GovernanceSharedState,
        sorting: ReferendumsSorting,
        basketItemsRepository: AnyDataProviderRepository<VotingBasketItemLocal>,
        votingBasketSubscriptionFactory: VotingBasketLocalSubscriptionFactoryProtocol,
        votingPowerSubscriptionFactory: VotingPowerLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.metaAccount = metaAccount
        self.governanceState = governanceState
        self.sorting = sorting
        self.basketItemsRepository = basketItemsRepository
        self.votingBasketSubscriptionFactory = votingBasketSubscriptionFactory
        self.votingPowerSubscriptionFactory = votingPowerSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: SwipeGovInteractorInputProtocol

extension SwipeGovInteractor: SwipeGovInteractorInputProtocol {
    func setup() {
        modelBuilder = SwipeGovModelBuilder(
            sorting: sorting,
            workingQueue: operationQueue
        ) { [weak self] result in
            self?.presenter?.didReceiveState(result)
        }
        startObservingState()

        votingPowerProvider = subscribeToVotingPowerProvider(
            for: chain.chainId,
            metaId: metaAccount.metaId
        )
        basketItemsProvider = subscribeToVotingBasketItemProvider(
            for: chain.chainId,
            metaId: metaAccount.metaId
        )

        clearAndSubscribeBalance()
    }

    func addVoting(
        with result: VoteResult,
        for referendumId: ReferendumIdLocal,
        votingPower: VotingPowerLocal
    ) {
        guard let voteType = VotingBasketItemLocal.VoteType(from: result) else {
            return
        }

        let conviction: VotingBasketConvictionLocal = switch voteType {
        case .abstain:
            .none
        case .aye, .nay:
            votingPower.conviction
        }

        let basketItem = VotingBasketItemLocal(
            referendumId: referendumId,
            chainId: chain.chainId,
            metaId: metaAccount.metaId,
            amount: votingPower.amount,
            voteType: voteType,
            conviction: conviction
        )

        let saveOperation = basketItemsRepository.saveOperation({ [basketItem] }, { [] })

        execute(
            operation: saveOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.logger.error("Unexpected voting error: \(error)")
            }
        }
    }
}

// MARK: VotingBasketLocalStorageSubscriber

extension SwipeGovInteractor: VotingBasketLocalStorageSubscriber, VotingBasketSubscriptionHandler {
    func handleVotingBasketItems(result: Result<[DataProviderChange<VotingBasketItemLocal>], any Error>) {
        switch result {
        case let .success(votingsChanges):
            modelBuilder?.apply(
                votingsChanges: votingsChanges,
                observableState.state.value
            )
        case let .failure(error):
            logger.error("Unexpected voting basket error: \(error)")
        }
    }
}

// MARK: VotingPowerLocalStorageSubscriber

extension SwipeGovInteractor: VotingPowerLocalStorageSubscriber, VotingPowerSubscriptionHandler {
    func handleVotingPowerChange(result: Result<[DataProviderChange<VotingPowerLocal>], any Error>) {
        switch result {
        case let .success(changes):
            guard let votingPower = changes.allChangedItems().first else {
                return
            }

            presenter?.didReceiveVotingPower(votingPower)
        case let .failure(error):
            logger.error("Unexpected voting power error: \(error)")
        }
    }
}

// MARK: Wallet Storage Subscription

extension SwipeGovInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            presenter?.didReceiveBalace(balance)
        case let .failure(error):
            logger.error("Unexpected balance error: \(error)")
        }
    }
}

// MARK: Private

private extension SwipeGovInteractor {
    func startObservingState() {
        observableState.addObserver(
            with: self,
            queue: .main
        ) { [weak self] _, new in
            self?.modelBuilder?.apply(new.value)
        }
    }

    func clearAndSubscribeBalance() {
        guard
            let accountId = metaAccount.fetch(for: chain.accountRequest())?.accountId,
            let assetId = chain.utilityAsset()?.assetId
        else {
            return
        }

        clear(streamableProvider: &assetBalanceProvider)

        assetBalanceProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chain.chainId,
            assetId: assetId
        )
    }
}

private extension VotingBasketItemLocal.VoteType {
    init?(from voteResult: VoteResult) {
        switch voteResult {
        case .aye:
            self = .aye
        case .nay:
            self = .nay
        case .abstain:
            self = .abstain
        case .skip:
            return nil
        }
    }
}
