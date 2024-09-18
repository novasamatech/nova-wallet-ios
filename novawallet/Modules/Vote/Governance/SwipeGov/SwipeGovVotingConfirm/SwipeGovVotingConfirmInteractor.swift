import Foundation
import SoraFoundation
import SubstrateSdk
import Operation_iOS

final class SwipeGovVotingConfirmInteractor: ReferendumVoteInteractor {
    var presenter: SwipeGovVotingConfirmInteractorOutputProtocol? {
        get {
            basePresenter as? SwipeGovVotingConfirmInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    private let signer: SigningWrapperProtocol
    private let observableState: ReferendumsObservableState
    private let repository: AnyDataProviderRepository<VotingBasketItemLocal>

    private let votingItems: [ReferendumIdLocal: VotingBasketItemLocal]
    private var itemsToClean: [ReferendumIdLocal: VotingBasketItemLocal] = [:]

    private var locksSubscription: StreamableProvider<AssetLock>?

    init(
        observableState: ReferendumsObservableState,
        repository: AnyDataProviderRepository<VotingBasketItemLocal>,
        referendumIndexes: [ReferendumIdLocal],
        votingItems: [ReferendumIdLocal: VotingBasketItemLocal],
        selectedAccount: MetaChainAccountResponse,
        chain: ChainModel,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        currencyManager: CurrencyManagerProtocol,
        extrinsicFactory: GovernanceExtrinsicFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        signer: SigningWrapperProtocol,
        feeProxy: MultiExtrinsicFeeProxyProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.observableState = observableState
        self.votingItems = votingItems
        self.signer = signer
        self.repository = repository

        super.init(
            referendumIndexes: referendumIndexes,
            selectedAccount: selectedAccount,
            chain: chain,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            referendumsSubscriptionFactory: referendumsSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            blockTimeService: blockTimeService,
            blockTimeFactory: blockTimeFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            currencyManager: currencyManager,
            extrinsicFactory: extrinsicFactory,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            lockStateFactory: lockStateFactory,
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
            guard let error = result.errors().first else {
                return
            }

            self?.cleanVotingList {
                self?.presenter?.didReceiveError(.submitVoteFailed(error))
            }
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

        votedReferendumsIds.forEach { index in
            if let item = votingItems[index] {
                itemsToClean[index] = item
            }
        }

        guard itemsToClean.keys == votingItems.keys else {
            return
        }

        cleanVotingList { [weak self] in
            self?.presenter?.didReceiveSuccessBatchVoting()
        }
    }

    func cleanVotingList(completion: @escaping () -> Void) {
        let deleteIds = Array(itemsToClean.values.map(\.identifier))

        guard !deleteIds.isEmpty else {
            completion()
            return
        }

        let deleteOperation = repository.saveOperation(
            { [] },
            { deleteIds }
        )

        execute(
            operation: deleteOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                completion()
            case let .failure(error):
                self?.presenter?.didReceiveError(.submitVoteFailed(error))
            }
        }
    }
}
