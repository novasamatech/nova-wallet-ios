import UIKit
import SubstrateSdk
import Operation_iOS

final class GovernanceYourDelegationsInteractor {
    weak var presenter: GovernanceYourDelegationsInteractorOutputProtocol?

    let selectedAccountId: AccountId
    let chain: ChainModel
    let lastVotedDays: Int
    let subscriptionFactory: GovernanceSubscriptionFactoryProtocol
    let referendumsOperationFactory: ReferendumsOperationFactoryProtocol
    let offchainOperationFactory: GovernanceDelegateListFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let timelineService: ChainTimelineFacadeProtocol
    let runtimeService: RuntimeProviderProtocol
    let govJsonProviderFactory: JsonDataProviderFactoryProtocol
    let operationQueue: OperationQueue

    private var delegateIds: Set<AccountId> = Set()
    private var currentBlockNumber: BlockNumber?

    private var metadataProvider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]>?
    private var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?

    private let tracksCallStore = CancellableCallStore()
    private let delegatesCallStore = CancellableCallStore()

    init(
        selectedAccountId: AccountId,
        chain: ChainModel,
        lastVotedDays: Int,
        subscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        referendumsOperationFactory: ReferendumsOperationFactoryProtocol,
        offchainOperationFactory: GovernanceDelegateListFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        timelineService: ChainTimelineFacadeProtocol,
        runtimeService: RuntimeProviderProtocol,
        govJsonProviderFactory: JsonDataProviderFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccountId = selectedAccountId
        self.chain = chain
        self.lastVotedDays = lastVotedDays
        self.subscriptionFactory = subscriptionFactory
        self.referendumsOperationFactory = referendumsOperationFactory
        self.offchainOperationFactory = offchainOperationFactory
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.timelineService = timelineService
        self.runtimeService = runtimeService
        self.govJsonProviderFactory = govJsonProviderFactory
        self.operationQueue = operationQueue
    }

    deinit {
        unsubscribeAccountVotes()
    }
}

// MARK: - Private

private extension GovernanceYourDelegationsInteractor {
    func fetchDelegatesIfNeeded() {
        guard !delegatesCallStore.hasCall else { return }

        if !delegateIds.isEmpty {
            let thresholdWrapper = timelineService.createTimepointThreshold(
                backIn: lastVotedDays
            )

            let delegateListWrapper: CompoundOperationWrapper<[GovernanceDelegateLocal]>
            delegateListWrapper = OperationCombiningService.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) { [weak self] in
                guard let self else {
                    throw BaseOperationError.parentOperationCancelled
                }

                let threshold = try thresholdWrapper.targetOperation.extractNoCancellableResultData()

                guard let threshold else {
                    throw BaseOperationError.unexpectedDependentResult
                }

                return offchainOperationFactory.fetchDelegateListByIdsWrapper(
                    from: delegateIds,
                    threshold: threshold
                )
            }

            delegateListWrapper.addDependency(wrapper: thresholdWrapper)

            let finalWrapper = delegateListWrapper.insertingHead(operations: thresholdWrapper.allOperations)

            executeCancellable(
                wrapper: finalWrapper,
                inOperationQueue: operationQueue,
                backingCallIn: delegatesCallStore,
                runningCallbackIn: .main
            ) { [weak self] result in
                switch result {
                case let .success(delegates):
                    self?.presenter?.didReceiveDelegates(delegates)
                case let .failure(error):
                    self?.presenter?.didReceiveError(.delegatesFetchFailed(error))
                }
            }
        } else {
            presenter?.didReceiveDelegates([])
        }
    }

    func fetchTracks() {
        let wrapper = referendumsOperationFactory.fetchAllTracks(runtimeProvider: runtimeService)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: tracksCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(tracks):
                self?.presenter?.didReceiveTracks(tracks)
            case let .failure(error):
                self?.presenter?.didReceiveError(.tracksFetchFailed(error))
            }
        }
    }

    func handleDelegations(from voting: ReferendumTracksVotingDistribution?) {
        guard let voting = voting else {
            return
        }

        let delegations = voting.votes.delegatings
        delegateIds = Set(delegations.values.map(\.target))

        presenter?.didReceiveDelegations(delegations)

        if currentBlockNumber != nil {
            fetchDelegatesIfNeeded()
        }
    }

    func unsubscribeAccountVotes() {
        subscriptionFactory.unsubscribeFromAccountVotes(self, accountId: selectedAccountId)
    }

    func subscribeAccountVotes() {
        unsubscribeAccountVotes()

        subscriptionFactory.subscribeToAccountVotes(self, accountId: selectedAccountId) { [weak self] result in
            switch result {
            case let .success(voting):
                self?.handleDelegations(from: voting.value)
            case let .failure(error):
                self?.presenter?.didReceiveError(.delegationsSubscriptionFailed(error))
            case .none:
                break
            }
        }
    }

    func subscribeBlockNumber() {
        blockNumberSubscription?.removeObserver(self)
        blockNumberSubscription = subscribeToBlockNumber(for: timelineService.timelineChainId)
    }

    func subscribeToDelegatesMetadata() {
        metadataProvider?.removeObserver(self)
        metadataProvider = subscribeDelegatesMetadata(for: chain)
    }
}

// MARK: - GovernanceYourDelegationsInteractorInputProtocol

extension GovernanceYourDelegationsInteractor: GovernanceYourDelegationsInteractorInputProtocol {
    func setup() {
        subscribeAccountVotes()
        subscribeBlockNumber()
        subscribeToDelegatesMetadata()
        fetchTracks()
    }

    func refreshDelegates() {
        if currentBlockNumber != nil {
            fetchDelegatesIfNeeded()
        }
    }

    func remakeSubscriptions() {
        subscribeAccountVotes()
        subscribeBlockNumber()
        subscribeToDelegatesMetadata()
    }

    func refreshTracks() {
        fetchTracks()
    }
}

// MARK: - GeneralLocalStorageSubscriber

extension GovernanceYourDelegationsInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(blockNumber):
            if let blockNumber = blockNumber {
                let optLastBlockNumber = currentBlockNumber
                currentBlockNumber = blockNumber

                if let lastBlockNumber = optLastBlockNumber, blockNumber.isNext(to: lastBlockNumber) {
                    return
                }

                fetchDelegatesIfNeeded()
            }
        case let .failure(error):
            presenter?.didReceiveError(.blockSubscriptionFailed(error))
        }
    }
}

// MARK: - GovJsonLocalStorageSubscriber

extension GovernanceYourDelegationsInteractor: GovJsonLocalStorageSubscriber, GovJsonLocalStorageHandler {
    func handleDelegatesMetadata(result: Result<[GovernanceDelegateMetadataRemote], Error>, chain _: ChainModel) {
        switch result {
        case let .success(metadata):
            presenter?.didReceiveMetadata(metadata)
        case let .failure(error):
            presenter?.didReceiveError(.metadataSubscriptionFailed(error))
        }
    }
}
