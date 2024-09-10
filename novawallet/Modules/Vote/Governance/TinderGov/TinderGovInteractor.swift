import Foundation
import Operation_iOS

class TinderGovInteractor {
    weak var presenter: TinderGovInteractorOutputProtocol?

    private let metaAccount: MetaAccountModel
    private let governanceState: GovernanceSharedState
    private let observableState: Observable<NotEqualWrapper<[ReferendumIdLocal: ReferendumLocal]>>
    private let sorting: ReferendumsSorting
    private let basketItemsRepository: AnyDataProviderRepository<VotingBasketItemLocal>
    private let operationQueue: OperationQueue

    private var modelBuilder: TinderGovModelBuilder?

    private var chain: ChainModel {
        governanceState.settings.value.chain
    }

    init(
        metaAccount: MetaAccountModel,
        observableState: Observable<NotEqualWrapper<[ReferendumIdLocal: ReferendumLocal]>>,
        governanceState: GovernanceSharedState,
        sorting: ReferendumsSorting,
        basketItemsRepository: AnyDataProviderRepository<VotingBasketItemLocal>,
        operationQueue: OperationQueue
    ) {
        self.metaAccount = metaAccount
        self.observableState = observableState
        self.governanceState = governanceState
        self.sorting = sorting
        self.basketItemsRepository = basketItemsRepository
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

        modelBuilder?.buildOnSetup()

        let fetchBasketOperation = basketItemsRepository.fetchAllOperation(with: RepositoryFetchOptions())

        execute(
            operation: fetchBasketOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(votings):
                onReceive(basketItems: votings)
                startObservingState()
            case let .failure(error):
                presenter?.didReceive(error)
            }
        }
    }

    func addVoting(
        with result: VoteResult,
        for referendumId: ReferendumIdLocal
    ) {
        guard let voteType = VotingBasketItemLocal.VoteType(from: result) else {
            return
        }

        let basketItem = VotingBasketItemLocal(
            referendumId: referendumId,
            chainId: chain.chainId,
            metaId: metaAccount.metaId,
            voteType: voteType,
            conviction: .none
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
            switch result {
            case let .success(success):
                self?.modelBuilder?.apply(voting: referendumId)
            case let .failure(error):
                self?.presenter?.didReceive(error)
            }
        }
    }
}

// MARK: Private

private extension TinderGovInteractor {
    func onReceive(basketItems: [VotingBasketItemLocal]) {
        let basketItemsIds = basketItems.map(\.referendumId)

        let referendums = filter(
            referendums: observableState.state.value,
            using: basketItemsIds
        )

        modelBuilder?.apply(referendums)
        modelBuilder?.apply(votings: basketItemsIds)
    }

    func filter(
        referendums: [ReferendumIdLocal: ReferendumLocal],
        using basketItemsIds: [ReferendumIdLocal]
    ) -> [ReferendumIdLocal: ReferendumLocal] {
        var mutReferendums = referendums

        basketItemsIds.forEach { mutReferendums[$0] = nil }

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
