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
    let runtimeService: RuntimeProviderProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let identityProxyFactory: IdentityProxyFactoryProtocol
    let timelineService: ChainTimelineFacadeProtocol
    let govJsonProviderFactory: JsonDataProviderFactoryProtocol
    let operationQueue: OperationQueue

    private var metadataProvider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]>?
    private var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?
    private var currentBlockNumber: BlockNumber?

    private var delegateDetailsCallStore = CancellableCallStore()

    init(
        selectedAccountId: AccountId?,
        delegate: AccountId,
        chain: ChainModel,
        lastVotedDays: Int,
        referendumOperationFactory: ReferendumsOperationFactoryProtocol,
        subscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        detailsOperationFactory: GovernanceDelegateStatsFactoryProtocol,
        runtimeService: RuntimeProviderProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        timelineService: ChainTimelineFacadeProtocol,
        govJsonProviderFactory: JsonDataProviderFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccountId = selectedAccountId
        delegateId = delegate
        self.chain = chain
        self.lastVotedDays = lastVotedDays
        self.detailsOperationFactory = detailsOperationFactory
        self.referendumOperationFactory = referendumOperationFactory
        self.subscriptionFactory = subscriptionFactory
        self.runtimeService = runtimeService
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.identityProxyFactory = identityProxyFactory
        self.timelineService = timelineService
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
        guard !delegateDetailsCallStore.hasCall else { return }

        let thresholdWrapper = timelineService.createTimepointThreshold(
            backIn: lastVotedDays
        )

        let delegateListWrapper: CompoundOperationWrapper<GovernanceDelegateDetails?>
        delegateListWrapper = OperationCombiningService.compoundOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let threshold = try thresholdWrapper.targetOperation.extractNoCancellableResultData()

            guard let threshold else { return nil }

            let delegateAddress = try delegateId.toAddress(using: chain.chainFormat)

            return detailsOperationFactory.fetchDetailsWrapper(
                for: delegateAddress,
                threshold: threshold
            )
        }

        delegateListWrapper.addDependency(wrapper: thresholdWrapper)

        let finalWrapper = delegateListWrapper.insertingHead(operations: thresholdWrapper.allOperations)

        executeCancellable(
            wrapper: finalWrapper,
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

    func subscribeBlockNumber() {
        blockNumberSubscription = subscribeToBlockNumber(for: timelineService.timelineChainId)
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
        subscribeBlockNumber()
        provideIdentity(for: delegateId)
        subscribeAccountVotes()
        subscribeToDelegatesMetadata()
        provideTracks()
    }

    func refreshDetails() {
        if currentBlockNumber != nil {
            fetchAndUpdateDetails()
        }
    }

    func remakeSubscriptions() {
        subscribeBlockNumber()

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

// MARK: - GeneralLocalStorageSubscriber

extension GovernanceDelegateInfoInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(blockNumber):
            if let blockNumber = blockNumber {
                let optLastBlockNumber = currentBlockNumber
                currentBlockNumber = blockNumber

                if let lastBlockNumber = optLastBlockNumber, blockNumber.isNext(to: lastBlockNumber) {
                    return
                }

                fetchAndUpdateDetails()
            }
        case let .failure(error):
            presenter?.didReceiveError(.blockSubscriptionFailed(error))
        }
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
