import Foundation
import Foundation_iOS
import SubstrateSdk
import Operation_iOS
import BigInt

final class SwipeGovVotingConfirmInteractor: ReferendumObservingVoteInteractor {
    var presenter: SwipeGovVotingConfirmInteractorOutputProtocol? {
        get { output as? SwipeGovVotingConfirmInteractorOutputProtocol }
        set { output = newValue }
    }

    private let signer: SigningWrapperProtocol
    private let repository: AnyDataProviderRepository<VotingBasketItemLocal>
    private let logger: LoggerProtocol

    private let votingItems: [ReferendumIdLocal: VotingBasketItemLocal]
    private var clearedItems: [ReferendumIdLocal: VotingBasketItemLocal] = [:]

    private var locksSubscription: StreamableProvider<AssetLock>?

    init(
        observableState: ReferendumsObservableState,
        repository: AnyDataProviderRepository<VotingBasketItemLocal>,
        votingItems: [ReferendumIdLocal: VotingBasketItemLocal],
        selectedAccount: MetaChainAccountResponse,
        chain: ChainModel,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        timelineService: ChainTimelineFacadeProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        currencyManager: CurrencyManagerProtocol,
        extrinsicFactory: GovernanceExtrinsicFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        signer: SigningWrapperProtocol,
        feeProxy: MultiExtrinsicFeeProxyProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        logger: LoggerProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.votingItems = votingItems
        self.signer = signer
        self.repository = repository
        self.logger = logger

        super.init(
            observableState: observableState,
            selectedAccount: selectedAccount,
            chain: chain,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            timelineService: timelineService,
            connection: connection,
            runtimeProvider: runtimeProvider,
            currencyManager: currencyManager,
            extrinsicFactory: extrinsicFactory,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            lockStateFactory: lockStateFactory,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
    }

    override func setup() {
        super.setup()

        clearAndSubscribeLocks()

        observableState.addObserver(
            with: self,
            queue: .main
        ) { [weak self] _, newState in
            self?.processNewState(newState.value)
        }
    }

    override func remakeSubscriptions() {
        super.remakeSubscriptions()

        clearAndSubscribeLocks()
    }

    override func handleAccountLocks(
        result: Result<[DataProviderChange<AssetLock>], Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(changes):
            let locks = changes.mergeToDict([:]).values
            presenter?.didReceiveLocks(Array(locks))
        case let .failure(error):
            presenter?.didReceiveError(.locksSubscriptionFailed(error))
        }
    }
}

// MARK: SwipeGovVotingConfirmInteractorInputProtocol

extension SwipeGovVotingConfirmInteractor: SwipeGovVotingConfirmInteractorInputProtocol {
    func submit(votes: [ReferendumNewVote]) {
        let splitter = createExtrinsicSplitter(for: votes)

        extrinsicService.submitWithTxSplitter(
            splitter,
            signer: signer,
            runningIn: .main
        ) { [weak self] result in
            let errors = result.errors()

            guard let error = errors.first else {
                if
                    let delayedCallSender = result.senders().first(
                        where: { $0.delayedCallExecution() }
                    ) {
                    self?.presenter?.didReceiveSuccessBatchVoting(delayedCallSender)
                }

                return
            }

            self?.logger.error("Failed to submit votes for \(errors.count) referenda")
            self?.presenter?.didReceiveError(.submitVoteFailed(error))
        }
    }
}

// MARK: Private

private extension SwipeGovVotingConfirmInteractor {
    func clearAndSubscribeLocks() {
        locksSubscription?.removeObserver(self)
        locksSubscription = nil

        guard let asset = chain.utilityAsset() else {
            return
        }

        locksSubscription = subscribeToLocksProvider(
            for: selectedAccount.chainAccount.accountId,
            chainId: chain.chainId,
            assetId: asset.assetId
        )
    }

    func processNewState(_ newState: ReferendumsState) {
        guard let votedReferendumsIds = newState.voting?.value?.votes.votes.keys else {
            return
        }

        let itemsToClear: [VotingBasketItemLocal] = votedReferendumsIds.compactMap {
            guard clearedItems[$0] == nil else {
                return nil
            }

            return votingItems[$0]
        }

        guard !itemsToClear.isEmpty else {
            return
        }

        clearVotingItems(itemsToClear)
    }

    func clearVotingItems(_ items: [VotingBasketItemLocal]) {
        let deleteIds = items.map(\.identifier)
        let deleteOperation = repository.saveOperation({
            []
        }, {
            deleteIds
        })

        execute(
            operation: deleteOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard case .success = result else {
                return
            }

            items.forEach { self?.clearedItems[$0.referendumId] = $0 }

            if self?.clearedItems.keys == self?.votingItems.keys {
                self?.presenter?.didReceiveSuccessBatchVoting(nil)
            }
        }
    }
}
