import Foundation
import Operation_iOS

class TinderGovInteractor {
    weak var presenter: TinderGovInteractorOutputProtocol?

    private let metaAccount: MetaAccountModel
    private let governanceState: GovernanceSharedState
    private let sorting: ReferendumsSorting
    private let basketItemsRepository: AnyDataProviderRepository<VotingBasketItemLocal>
    private let operationQueue: OperationQueue

    private var basketItemsProvider: StreamableProvider<VotingBasketItemLocal>?
    private var votingPowerProvider: StreamableProvider<VotingPowerLocal>?

    private var modelBuilder: TinderGovModelBuilder?
    private var votingPower: VotingPowerLocal?
    
    private var observableState: Observable<NotEqualWrapper<[ReferendumIdLocal: ReferendumLocal]>> {
        governanceState.tinderGovObservableState
    }

    private var chain: ChainModel {
        governanceState.settings.value.chain
    }

    let votingBasketSubscriptionFactory: VotingBasketLocalSubscriptionFactoryProtocol
    let votingPowerSubscriptionFactory: VotingPowerLocalSubscriptionFactoryProtocol

    init(
        metaAccount: MetaAccountModel,
        governanceState: GovernanceSharedState,
        sorting: ReferendumsSorting,
        basketItemsRepository: AnyDataProviderRepository<VotingBasketItemLocal>,
        votingBasketSubscriptionFactory: VotingBasketLocalSubscriptionFactoryProtocol,
        votingPowerSubscriptionFactory: VotingPowerLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.metaAccount = metaAccount
        self.governanceState = governanceState
        self.sorting = sorting
        self.basketItemsRepository = basketItemsRepository
        self.votingBasketSubscriptionFactory = votingBasketSubscriptionFactory
        self.votingPowerSubscriptionFactory = votingPowerSubscriptionFactory
        self.operationQueue = operationQueue
    }
}

// MARK: TinderGovInteractorInputProtocol

extension TinderGovInteractor: TinderGovInteractorInputProtocol {
    func setup() {
        modelBuilder = .init(
            sorting: sorting,
            workingQueue: operationQueue
        ) { [weak self] result in
            self?.presenter?.didReceive(result)
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
    }

    func addVoting(
        with result: VoteResult,
        for referendumId: ReferendumIdLocal
    ) {
        guard
            let voteType = VotingBasketItemLocal.VoteType(from: result),
            let votingPower
        else {
            return
        }

        let basketItem = VotingBasketItemLocal(
            referendumId: referendumId,
            chainId: chain.chainId,
            metaId: metaAccount.metaId,
            amount: votingPower.amount,
            voteType: voteType,
            conviction: votingPower.conviction
        )

        let saveOperation = basketItemsRepository.saveOperation(
            { [basketItem] },
            { [] }
        )

        execute(
            operation: saveOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.presenter?.didReceive(error)
            }
        }
    }
}

// MARK: VotingBasketLocalStorageSubscriber

extension TinderGovInteractor: VotingBasketLocalStorageSubscriber, VotingBasketSubscriptionHandler {
    func handleVotingBasketItems(result: Result<[DataProviderChange<VotingBasketItemLocal>], any Error>) {
        switch result {
        case let .success(votingsChanges):
            modelBuilder?.apply(
                votingsChanges: votingsChanges,
                observableState.state.value
            )
        case let .failure(error):
            presenter?.didReceive(error)
        }
    }
}

// MARK: VotingBasketLocalStorageSubscriber

extension TinderGovInteractor: VotingPowerLocalStorageSubscriber, VotingPowerSubscriptionHandler {
    func handleVotingPowerChange(result: Result<[DataProviderChange<VotingPowerLocal>], any Error>) {
        switch result {
        case let .success(changes):
            guard let votingPower = changes.allChangedItems().first else {
                return
            }
            self.votingPower = votingPower
            presenter?.didReceive(votingPower)
        case let .failure(error):
            presenter?.didReceive(error)
        }
    }
}

// MARK: Private

private extension TinderGovInteractor {
    func filter(
        referendums: [ReferendumIdLocal: ReferendumLocal],
        using basketItemsChanges: [DataProviderChange<VotingBasketItemLocal>]
    ) -> [ReferendumIdLocal: ReferendumLocal] {
        var mutReferendums = referendums

        basketItemsChanges
            .compactMap(\.item)
            .forEach { mutReferendums[$0.referendumId] = nil }

        return mutReferendums
    }

    func startObservingState() {
        observableState.addObserver(
            with: self,
            queue: .main
        ) { [weak self] _, new in
            self?.modelBuilder?.apply(new.value)
        }
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
