import UIKit
import SubstrateSdk
import Operation_iOS

final class GovernanceDelegateInfoInteractor {
    weak var presenter: GovernanceDelegateInfoInteractorOutputProtocol?

    let selectedAccountId: AccountId?
    let delegateId: AccountId
    let chain: ChainModel
    let lastVotedDays: Int
    let referendumOperationFactory: ReferendumsOperationFactoryProtocol
    let subscriptionFactory: GovernanceSubscriptionFactoryProtocol
    let detailsOperationFactory: GovernanceDelegateStatsFactoryProtocol
    let timepointThresholdService: TimepointThresholdServiceProtocol
    let runtimeService: RuntimeProviderProtocol
    let identityProxyFactory: IdentityProxyFactoryProtocol
    let govJsonProviderFactory: JsonDataProviderFactoryProtocol
    let operationQueue: OperationQueue

    private var metadataProvider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]>?
    private var currentThreshold: TimepointThreshold?

    private var delegateDetailsCallStore = CancellableCallStore()

    init(
        selectedAccountId: AccountId?,
        delegate: AccountId,
        chain: ChainModel,
        lastVotedDays: Int,
        referendumOperationFactory: ReferendumsOperationFactoryProtocol,
        subscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        detailsOperationFactory: GovernanceDelegateStatsFactoryProtocol,
        timepointThresholdService: TimepointThresholdServiceProtocol,
        runtimeService: RuntimeProviderProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        govJsonProviderFactory: JsonDataProviderFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccountId = selectedAccountId
        delegateId = delegate
        self.chain = chain
        self.lastVotedDays = lastVotedDays
        self.detailsOperationFactory = detailsOperationFactory
        self.timepointThresholdService = timepointThresholdService
        self.referendumOperationFactory = referendumOperationFactory
        self.subscriptionFactory = subscriptionFactory
        self.runtimeService = runtimeService
        self.identityProxyFactory = identityProxyFactory
        self.govJsonProviderFactory = govJsonProviderFactory
        self.operationQueue = operationQueue
    }

    deinit {
        unsubscribeAccountVotes()
    }
}

// MARK: - Private

private extension GovernanceDelegateInfoInteractor {
    func provideTracks() {
        let wrapper = referendumOperationFactory.fetchAllTracks(runtimeProvider: runtimeService)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(tracks):
                self?.presenter?.didReceiveTracks(tracks)
            case let .failure(error):
                self?.presenter?.didReceiveError(GovernanceDelegateInfoError.tracksFetchFailed(error))
            }
        }
    }

    func unsubscribeAccountVotes() {
        guard let selectedAccountId = selectedAccountId else {
            return
        }

        subscriptionFactory.unsubscribeFromAccountVotes(self, accountId: selectedAccountId)
    }

    func subscribeAccountVotes() {
        guard let selectedAccountId = selectedAccountId else {
            presenter?.didReceiveVotingResult(.init(value: nil, blockHash: nil))
            return
        }

        unsubscribeAccountVotes()

        subscriptionFactory.subscribeToAccountVotes(
            self,
            accountId: selectedAccountId
        ) { [weak self] result in
            switch result {
            case let .success(votingResult):
                self?.presenter?.didReceiveVotingResult(votingResult)
            case let .failure(error):
                self?.presenter?.didReceiveError(
                    GovernanceDelegateInfoError.votesSubscriptionFailed(error)
                )
            case .none:
                break
            }
        }
    }

    func fetchAndUpdateDetails() {
        guard
            !delegateDetailsCallStore.hasCall,
            let currentThreshold,
            let delegateAddress = try? delegateId.toAddress(using: chain.chainFormat)
        else { return }

        let threshold = currentThreshold.backIn(
            seconds: TimeInterval(lastVotedDays).secondsFromDays
        )

        let wrapper = detailsOperationFactory.fetchDetailsWrapper(
            for: delegateAddress,
            threshold: threshold
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: delegateDetailsCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(details):
                self?.presenter?.didReceiveDetails(details)
            case let .failure(error):
                self?.presenter?.didReceiveError(.detailsFetchFailed(error))
            }
        }
    }

    func subscribeTimepointThreshold() {
        timepointThresholdService.remove(observer: self)

        timepointThresholdService.add(
            observer: self,
            sendStateOnSubscription: true
        ) { [weak self] _, timepointThreshold in
            guard let self, let timepointThreshold else { return }
            let previousThreshold = currentThreshold
            currentThreshold = timepointThreshold

            if
                case let .block(newBlockNumber, _) = timepointThreshold.type,
                case let .block(previousBlockNumber, _) = previousThreshold?.type,
                newBlockNumber.isNext(to: previousBlockNumber) {
                return
            }

            fetchAndUpdateDetails()
        }
    }

    func subscribeToDelegatesMetadata() {
        metadataProvider?.removeObserver(self)
        metadataProvider = subscribeDelegatesMetadata(for: chain)
    }

    func provideIdentity(for delegate: AccountId) {
        let wrapper = identityProxyFactory.createIdentityWrapper(for: { [delegate] })

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(identities):
                self?.presenter?.didReceiveIdentity(identities.first?.value)
            case let .failure(error):
                self?.presenter?.didReceiveError(.identityFetchFailed(error))
            }
        }
    }
}

// MARK: - GovernanceDelegateInfoInteractorInputProtocol

extension GovernanceDelegateInfoInteractor: GovernanceDelegateInfoInteractorInputProtocol {
    func setup() {
        timepointThresholdService.setup()

        subscribeTimepointThreshold()
        provideIdentity(for: delegateId)
        subscribeAccountVotes()
        subscribeToDelegatesMetadata()
        provideTracks()
    }

    func refreshDetails() {
        guard currentThreshold != nil else { return }

        fetchAndUpdateDetails()
    }

    func remakeSubscriptions() {
        subscribeTimepointThreshold()

        subscribeToDelegatesMetadata()

        subscribeAccountVotes()
    }

    func refreshIdentity() {
        provideIdentity(for: delegateId)
    }

    func refreshTracks() {
        provideTracks()
    }
}

// MARK: - GovJsonLocalStorageSubscriber

extension GovernanceDelegateInfoInteractor: GovJsonLocalStorageSubscriber, GovJsonLocalStorageHandler {
    func handleDelegatesMetadata(result: Result<[GovernanceDelegateMetadataRemote], Error>, chain: ChainModel) {
        switch result {
        case let .success(metadata):
            let address = try? delegateId.toAddress(using: chain.chainFormat)
            let delegateMetadata = metadata.first { $0.address == address }
            presenter?.didReceiveMetadata(delegateMetadata)
        case let .failure(error):
            presenter?.didReceiveError(.metadataSubscriptionFailed(error))
        }
    }
}
