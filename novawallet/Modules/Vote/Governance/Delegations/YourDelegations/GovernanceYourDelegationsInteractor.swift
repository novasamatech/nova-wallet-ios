import UIKit
import SubstrateSdk
import Operation_iOS

final class GovernanceYourDelegationsInteractor: AnyCancellableCleaning {
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
    private var blockTimeCancellable: CancellableCall?
    private var tracksCancellable: CancellableCall?
    private var delegatesCancellable: CancellableCall?

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

    private func fetchBlockTimeAndUpdateDelegates() {
        clear(cancellable: &blockTimeCancellable)

        let blockTimeUpdateWrapper = timelineService.createBlockTimeOperation()

        blockTimeUpdateWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.blockTimeCancellable === blockTimeUpdateWrapper else {
                    return
                }

                self?.blockTimeCancellable = nil

                do {
                    let blockTime = try blockTimeUpdateWrapper.targetOperation.extractNoCancellableResultData()

                    self?.fetchDelegatesIfNeeded(for: blockTime)
                } catch {
                    self?.presenter?.didReceiveError(.blockTimeFetchFailed(error))
                }
            }
        }

        blockTimeCancellable = blockTimeUpdateWrapper

        operationQueue.addOperations(blockTimeUpdateWrapper.allOperations, waitUntilFinished: false)
    }

    private func fetchDelegatesIfNeeded(for blockTime: BlockTime) {
        guard
            let activityBlockNumber = currentBlockNumber?.blockBackInDays(
                lastVotedDays, blockTime: blockTime
            ) else {
            return
        }

        clear(cancellable: &delegatesCancellable)

        if !delegateIds.isEmpty {
            let wrapper = offchainOperationFactory.fetchDelegateListByIdsWrapper(
                from: delegateIds,
                activityStartBlock: activityBlockNumber
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

        if currentBlockNumber != nil {
            fetchBlockTimeAndUpdateDelegates()
        }
    }

    private func unsubscribeAccountVotes() {
        subscriptionFactory.unsubscribeFromAccountVotes(self, accountId: selectedAccountId)
    }

    private func subscribeAccountVotes() {
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

    private func subscribeBlockNumber() {
        blockNumberSubscription?.removeObserver(self)
        blockNumberSubscription = subscribeToBlockNumber(for: timelineService.timelineChainId)
    }

    private func subscribeToDelegatesMetadata() {
        metadataProvider?.removeObserver(self)
        metadataProvider = subscribeDelegatesMetadata(for: chain)
    }
}

extension GovernanceYourDelegationsInteractor: GovernanceYourDelegationsInteractorInputProtocol {
    func setup() {
        subscribeAccountVotes()
        subscribeBlockNumber()
        subscribeToDelegatesMetadata()
        fetchTracks()
    }

    func refreshDelegates() {
        if currentBlockNumber != nil {
            fetchBlockTimeAndUpdateDelegates()
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

                fetchBlockTimeAndUpdateDelegates()
            }
        case let .failure(error):
            presenter?.didReceiveError(.blockSubscriptionFailed(error))
        }
    }
}

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
