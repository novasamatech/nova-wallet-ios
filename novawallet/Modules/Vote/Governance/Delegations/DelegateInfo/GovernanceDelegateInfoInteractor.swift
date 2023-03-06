import UIKit
import SubstrateSdk
import RobinHood

final class GovernanceDelegateInfoInteractor {
    weak var presenter: GovernanceDelegateInfoInteractorOutputProtocol?

    let selectedAccountId: AccountId?
    let delegateId: AccountId
    let chain: ChainModel
    let lastVotedDays: Int
    let referendumOperationFactory: ReferendumsOperationFactoryProtocol
    let subscriptionFactory: GovernanceSubscriptionFactoryProtocol
    let detailsOperationFactory: GovernanceDelegateStatsFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeProviderProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let blockTimeFactory: BlockTimeOperationFactoryProtocol
    let govJsonProviderFactory: JsonDataProviderFactoryProtocol
    let operationQueue: OperationQueue

    private var metadataProvider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]>?
    private var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?
    private var currentBlockNumber: BlockNumber?

    init(
        selectedAccountId: AccountId?,
        delegate: AccountId,
        chain: ChainModel,
        lastVotedDays: Int,
        referendumOperationFactory: ReferendumsOperationFactoryProtocol,
        subscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        detailsOperationFactory: GovernanceDelegateStatsFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeProviderProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
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
        self.connection = connection
        self.runtimeService = runtimeService
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.identityOperationFactory = identityOperationFactory
        self.blockTimeService = blockTimeService
        self.blockTimeFactory = blockTimeFactory
        self.govJsonProviderFactory = govJsonProviderFactory
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

    private func fetchBlockTimeAndUpdateDetails() {
        let blockTimeUpdateWrapper = blockTimeFactory.createBlockTimeOperation(
            from: runtimeService,
            blockTimeEstimationService: blockTimeService
        )

        blockTimeUpdateWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let blockTime = try blockTimeUpdateWrapper.targetOperation.extractNoCancellableResultData()

                    self?.fetchDetails(for: blockTime)
                } catch {
                    self?.presenter?.didReceiveError(.blockTimeFetchFailed(error))
                }
            }
        }

        operationQueue.addOperations(blockTimeUpdateWrapper.allOperations, waitUntilFinished: false)
    }

    private func fetchDetails(for blockTime: BlockTime) {
        do {
            guard
                let activityBlockNumber = currentBlockNumber?.blockBackInDays(
                    lastVotedDays,
                    blockTime: blockTime
                ) else {
                return
            }

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

    private func subscribeToDelegatesMetadata() {
        metadataProvider?.removeObserver(self)
        metadataProvider = subscribeDelegatesMetadata(for: chain)
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
        provideIdentity(for: delegateId)
        subscribeAccountVotes()
        subscribeToDelegatesMetadata()
        provideTracks()
    }

    func refreshDetails() {
        if currentBlockNumber != nil {
            fetchBlockTimeAndUpdateDetails()
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

                fetchBlockTimeAndUpdateDetails()
            }
        case let .failure(error):
            presenter?.didReceiveError(.blockSubscriptionFailed(error))
        }
    }
}

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
