import UIKit
import SubstrateSdk
import RobinHood

final class GovernanceDelegateInfoInteractor {
    weak var presenter: GovernanceDelegateInfoInteractorOutputProtocol?

    let selectedAccountId: AccountId?
    let delegateId: AccountId
    let chain: ChainModel
    let lastVotedDays: Int
    let fetchBlockTreshold: BlockNumber
    let referendumOperationFactory: ReferendumsOperationFactoryProtocol
    let subscriptionFactory: GovernanceSubscriptionFactoryProtocol
    let detailsOperationFactory: GovernanceDelegateStatsFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeProviderProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let metadataProvider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]>
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let blockTimeFactory: BlockTimeOperationFactoryProtocol
    let operationQueue: OperationQueue

    private var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?
    private var lastUsedBlockNumber: BlockNumber?
    private var currentBlockNumber: BlockNumber?
    private var currentBlockTime: BlockTime?

    init(
        selectedAccountId: AccountId?,
        delegate: AccountId,
        chain: ChainModel,
        lastVotedDays: Int,
        fetchBlockTreshold: BlockNumber,
        referendumOperationFactory: ReferendumsOperationFactoryProtocol,
        subscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        detailsOperationFactory: GovernanceDelegateStatsFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeProviderProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        metadataProvider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]>,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccountId = selectedAccountId
        delegateId = delegate
        self.chain = chain
        self.lastVotedDays = lastVotedDays
        self.fetchBlockTreshold = fetchBlockTreshold
        self.detailsOperationFactory = detailsOperationFactory
        self.referendumOperationFactory = referendumOperationFactory
        self.subscriptionFactory = subscriptionFactory
        self.connection = connection
        self.runtimeService = runtimeService
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.metadataProvider = metadataProvider
        self.identityOperationFactory = identityOperationFactory
        self.blockTimeService = blockTimeService
        self.blockTimeFactory = blockTimeFactory
        self.operationQueue = operationQueue
    }

    deinit {
        unsubscribeAccountVotes()
    }

    private func provideTracks() {
        let wrapper = referendumOperationFactory.fetchAllTracks(runtimeProvider: runtimeService)

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let tracks = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveTracks(tracks)
                } catch {
                    self?.presenter?.didReceiveError(
                        GovernanceDelegateInfoError.tracksFetchFailed(error)
                    )
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func unsubscribeAccountVotes() {
        guard let selectedAccountId = selectedAccountId else {
            return
        }

        subscriptionFactory.unsubscribeFromAccountVotes(self, accountId: selectedAccountId)
    }

    private func subscribeAccountVotes() {
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

    private func updateBlockTime() {
        let blockTimeUpdateWrapper = blockTimeFactory.createBlockTimeOperation(
            from: runtimeService,
            blockTimeEstimationService: blockTimeService
        )

        blockTimeUpdateWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let blockTime = try blockTimeUpdateWrapper.targetOperation.extractNoCancellableResultData()
                    self?.currentBlockTime = blockTime

                    self?.fetchDetailsIfNeeded()
                } catch {
                    self?.presenter?.didReceiveError(.blockTimeFetchFailed(error))
                }
            }
        }

        operationQueue.addOperations(blockTimeUpdateWrapper.allOperations, waitUntilFinished: false)
    }

    private func fetchDetailsIfNeeded() {
        do {
            guard
                let activityBlockNumber = currentBlockNumber?.blockBackInDays(
                    lastVotedDays,
                    blockTime: currentBlockTime
                ) else {
                return
            }

            if
                let lastUsedBlockNumber = lastUsedBlockNumber,
                activityBlockNumber > lastUsedBlockNumber,
                activityBlockNumber - lastUsedBlockNumber < fetchBlockTreshold {
                return
            }

            lastUsedBlockNumber = activityBlockNumber

            let delegateAddress = try delegateId.toAddress(using: chain.chainFormat)

            let wrapper = detailsOperationFactory.fetchDetailsWrapper(
                for: delegateAddress,
                activityStartBlock: activityBlockNumber
            )

            wrapper.targetOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    do {
                        let details = try wrapper.targetOperation.extractNoCancellableResultData()
                        self?.presenter?.didReceiveDetails(details)
                    } catch {
                        self?.presenter?.didReceiveError(.detailsFetchFailed(error))
                    }
                }
            }

            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        } catch {
            presenter?.didReceiveError(.detailsFetchFailed(error))
        }
    }

    private func subscribeBlockNumber() {
        blockNumberSubscription = subscribeToBlockNumber(for: chain.chainId)
    }

    private func subscribeMetadata(for delegate: AccountId) {
        let updateClosure: ([DataProviderChange<[GovernanceDelegateMetadataRemote]>]) -> Void = { [weak self] changes in
            let metadata = changes.reduceToLastChange()?.first {
                (try? $0.address.toAccountId()) == delegate
            }

            self?.presenter?.didReceiveMetadata(metadata)
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter?.didReceiveError(.metadataSubscriptionFailed(error))
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false, waitsInProgressSyncOnAdd: false)

        metadataProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func clearMetadataSubscription() {
        metadataProvider.removeObserver(self)
    }

    private func provideIdentity(for delegate: AccountId) {
        let wrapper = identityOperationFactory.createIdentityWrapper(
            for: { [delegate] },
            engine: connection,
            runtimeService: runtimeService,
            chainFormat: chain.chainFormat
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let identity = try wrapper.targetOperation.extractNoCancellableResultData().first?.value
                    self?.presenter?.didReceiveIdentity(identity)
                } catch {
                    self?.presenter?.didReceiveError(.identityFetchFailed(error))
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

extension GovernanceDelegateInfoInteractor: GovernanceDelegateInfoInteractorInputProtocol {
    func setup() {
        subscribeBlockNumber()
        subscribeMetadata(for: delegateId)
        provideIdentity(for: delegateId)
        subscribeAccountVotes()
        provideTracks()
    }

    func refreshDetails() {
        lastUsedBlockNumber = nil
        fetchDetailsIfNeeded()
    }

    func remakeSubscriptions() {
        subscribeBlockNumber()

        clearMetadataSubscription()
        subscribeMetadata(for: delegateId)

        subscribeAccountVotes()
    }

    func refreshIdentity() {
        provideIdentity(for: delegateId)
    }

    func refreshTracks() {
        provideTracks()
    }
}

extension GovernanceDelegateInfoInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(blockNumber):
            if let blockNumber = blockNumber {
                currentBlockNumber = blockNumber

                updateBlockTime()
            }
        case let .failure(error):
            presenter?.didReceiveError(.blockSubscriptionFailed(error))
        }
    }
}
