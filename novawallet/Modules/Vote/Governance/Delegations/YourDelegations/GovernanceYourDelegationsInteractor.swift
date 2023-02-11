import UIKit
import SubstrateSdk
import RobinHood

final class GovernanceYourDelegationsInteractor: AnyCancellableCleaning {
    weak var presenter: GovernanceYourDelegationsInteractorOutputProtocol?

    let selectedAccountId: AccountId
    let chain: ChainModel
    let lastVotedDays: Int
    let fetchBlockTreshold: BlockNumber
    let subscriptionFactory: GovernanceSubscriptionFactoryProtocol
    let referendumsOperationFactory: ReferendumsOperationFactoryProtocol
    let offchainOperationFactory: GovernanceDelegateListFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let blockTimeFactory: BlockTimeOperationFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeProviderProtocol
    let operationQueue: OperationQueue

    private var delegateIds: Set<AccountId> = Set()
    private var currentBlockNumber: BlockNumber?
    private var currentBlockTime: BlockTime?
    private var lastUsedBlockNumber: BlockNumber?

    private var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?
    private var blockTimeCancellable: CancellableCall?
    private var tracksCancellable: CancellableCall?
    private var delegatesCancellable: CancellableCall?

    init(
        selectedAccountId: AccountId,
        chain: ChainModel,
        lastVotedDays: Int,
        fetchBlockTreshold: BlockNumber,
        subscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        referendumsOperationFactory: ReferendumsOperationFactoryProtocol,
        offchainOperationFactory: GovernanceDelegateListFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeProviderProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccountId = selectedAccountId
        self.chain = chain
        self.lastVotedDays = lastVotedDays
        self.fetchBlockTreshold = fetchBlockTreshold
        self.subscriptionFactory = subscriptionFactory
        self.referendumsOperationFactory = referendumsOperationFactory
        self.offchainOperationFactory = offchainOperationFactory
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.blockTimeService = blockTimeService
        self.blockTimeFactory = blockTimeFactory
        self.connection = connection
        self.runtimeService = runtimeService
        self.operationQueue = operationQueue
    }

    private func updateBlockTime() {
        clear(cancellable: &blockTimeCancellable)

        let blockTimeUpdateWrapper = blockTimeFactory.createBlockTimeOperation(
            from: runtimeService,
            blockTimeEstimationService: blockTimeService
        )

        blockTimeUpdateWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.blockTimeCancellable === blockTimeUpdateWrapper else {
                    return
                }

                self?.blockTimeCancellable = nil

                do {
                    let blockTime = try blockTimeUpdateWrapper.targetOperation.extractNoCancellableResultData()
                    self?.currentBlockTime = blockTime

                    self?.fetchDelegatesIfNeeded()
                } catch {
                    self?.presenter?.didReceiveError(.blockTimeFetchFailed(error))
                }
            }
        }

        blockTimeCancellable = blockTimeUpdateWrapper

        operationQueue.addOperations(blockTimeUpdateWrapper.allOperations, waitUntilFinished: false)
    }

    private func fetchDelegatesIfNeeded(_ forced: Bool = false) {
        guard
            let activityBlockNumber = currentBlockNumber?.blockBackInDays(
                lastVotedDays, blockTime: currentBlockTime
            ) else {
            return
        }

        if
            !forced,
            let lastUsedBlockNumber = lastUsedBlockNumber,
            activityBlockNumber > lastUsedBlockNumber,
            activityBlockNumber - lastUsedBlockNumber < fetchBlockTreshold {
            return
        }

        lastUsedBlockNumber = activityBlockNumber

        clear(cancellable: &delegatesCancellable)

        if !delegateIds.isEmpty {
            let wrapper = offchainOperationFactory.fetchDelegateListByIdsWrapper(
                from: delegateIds,
                activityStartBlock: activityBlockNumber,
                chain: chain,
                connection: connection,
                runtimeService: runtimeService
            )

            wrapper.targetOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    guard self?.delegatesCancellable === wrapper else {
                        return
                    }

                    self?.delegatesCancellable = nil

                    do {
                        let delegates = try wrapper.targetOperation.extractNoCancellableResultData()
                        self?.presenter?.didReceiveDelegates(delegates)
                    } catch {
                        self?.presenter?.didReceiveError(.delegatesFetchFailed(error))
                    }
                }
            }

            delegatesCancellable = wrapper

            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        } else {
            presenter?.didReceiveDelegates([])
        }
    }

    private func fetchTracks() {
        clear(cancellable: &tracksCancellable)

        let wrapper = referendumsOperationFactory.fetchAllTracks(runtimeProvider: runtimeService)

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.tracksCancellable === wrapper else {
                    return
                }

                self?.tracksCancellable = nil

                do {
                    let tracks = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveTracks(tracks)
                } catch {
                    self?.presenter?.didReceiveError(.tracksFetchFailed(error))
                }
            }
        }

        tracksCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func handleDelegations(from voting: ReferendumTracksVotingDistribution?) {
        guard let voting = voting else {
            return
        }

        let delegations = voting.votes.delegatings
        delegateIds = Set(delegations.values.map(\.target))

        presenter?.didReceiveDelegations(delegations)

        fetchDelegatesIfNeeded(true)
    }

    private func subscribeAccountVotes() {
        subscriptionFactory.unsubscribeFromAccountVotes(self, accountId: selectedAccountId)

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

    private func subscribeBlockNumber() {
        blockNumberSubscription = subscribeToBlockNumber(for: chain.chainId)
    }
}

extension GovernanceYourDelegationsInteractor: GovernanceYourDelegationsInteractorInputProtocol {
    func setup() {
        subscribeAccountVotes()
        subscribeBlockNumber()
        fetchTracks()
    }

    func refreshDelegates() {
        fetchDelegatesIfNeeded()
    }

    func remakeSubscriptions() {
        subscribeAccountVotes()
        subscribeBlockNumber()
    }

    func refreshTracks() {
        fetchTracks()
    }
}

extension GovernanceYourDelegationsInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
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
