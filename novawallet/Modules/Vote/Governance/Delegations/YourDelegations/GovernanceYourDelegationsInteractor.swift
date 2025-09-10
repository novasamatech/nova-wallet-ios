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
    let timepointThresholdStore: TimepointThresholdStoreProtocol
    let runtimeService: RuntimeProviderProtocol
    let govJsonProviderFactory: JsonDataProviderFactoryProtocol
    let operationQueue: OperationQueue

    private var delegateIds: Set<AccountId> = Set()
    private var currentThreshold: TimepointThreshold?

    private var metadataProvider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]>?

    private let tracksCallStore = CancellableCallStore()
    private let delegatesCallStore = CancellableCallStore()

    init(
        selectedAccountId: AccountId,
        chain: ChainModel,
        lastVotedDays: Int,
        subscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        referendumsOperationFactory: ReferendumsOperationFactoryProtocol,
        offchainOperationFactory: GovernanceDelegateListFactoryProtocol,
        timepointThresholdStore: TimepointThresholdStoreProtocol,
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
        self.timepointThresholdStore = timepointThresholdStore
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

        if !delegateIds.isEmpty, let currentThreshold {
            let thresholdBackInDays = currentThreshold.backIn(days: lastVotedDays)

            let wrapper = offchainOperationFactory.fetchDelegateListByIdsWrapper(
                from: delegateIds,
                threshold: thresholdBackInDays
            )

            executeCancellable(
                wrapper: wrapper,
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

        guard currentThreshold != nil else { return }

        fetchDelegatesIfNeeded()
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

    func subscribeTimepointThreshold() {
        timepointThresholdStore.remove(observer: self)

        timepointThresholdStore.add(
            observer: self,
            sendStateOnSubscription: true
        ) { [weak self] _, timepointThreshold in
            guard let self, let timepointThreshold else { return }
            let previousThreshold = currentThreshold
            currentThreshold = timepointThreshold

            if
                case let .block(newBlockNumber, _) = timepointThreshold,
                case let .block(previousBlockNumber, _) = previousThreshold,
                newBlockNumber.isNext(to: previousBlockNumber) {
                return
            }

            fetchDelegatesIfNeeded()
        }
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
        subscribeTimepointThreshold()
        subscribeToDelegatesMetadata()
        fetchTracks()
    }

    func refreshDelegates() {
        guard currentThreshold != nil else { return }

        fetchDelegatesIfNeeded()
    }

    func remakeSubscriptions() {
        subscribeAccountVotes()
        subscribeTimepointThreshold()
        subscribeToDelegatesMetadata()
    }

    func refreshTracks() {
        fetchTracks()
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
