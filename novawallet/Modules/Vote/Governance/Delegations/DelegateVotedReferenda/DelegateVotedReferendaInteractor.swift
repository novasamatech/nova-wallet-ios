import UIKit
import Operation_iOS
import SubstrateSdk

final class DelegateVotedReferendaInteractor: AnyCancellableCleaning {
    weak var presenter: DelegateVotedReferendaInteractorOutputProtocol!

    let address: AccountAddress
    let governanceOption: GovernanceSelectedOption
    let connection: JSONRPCEngine
    let runtimeService: RuntimeProviderProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol
    let fetchFactory: DelegateVotedReferendaOperationFactoryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    let dataFetchOption: DelegateVotedReferendaOption
    let operationQueue: OperationQueue

    private var currentBlockNumber: BlockNumber?

    private(set) var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?
    private(set) var metadataProvider: StreamableProvider<ReferendumMetadataLocal>?

    var referendumsCancellable: CancellableCall?
    var blockTimeCancellable: CancellableCall?
    var offchainVotingCancellable: CancellableCall?

    init(
        address: AccountAddress,
        governanceOption: GovernanceSelectedOption,
        connection: JSONRPCEngine,
        runtimeService: RuntimeProviderProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol,
        fetchFactory: DelegateVotedReferendaOperationFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeOperationFactory: BlockTimeOperationFactoryProtocol,
        dataFetchOption: DelegateVotedReferendaOption,
        operationQueue: OperationQueue
    ) {
        self.address = address
        self.governanceOption = governanceOption
        self.connection = connection
        self.runtimeService = runtimeService
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.govMetadataLocalSubscriptionFactory = govMetadataLocalSubscriptionFactory
        self.fetchFactory = fetchFactory
        self.blockTimeService = blockTimeService
        self.blockTimeOperationFactory = blockTimeOperationFactory
        self.dataFetchOption = dataFetchOption
        self.operationQueue = operationQueue
    }

    deinit {
        clearCancellable()
    }

    func clearCancellable() {
        clear(cancellable: &referendumsCancellable)
        clear(cancellable: &blockTimeCancellable)
    }

    func subscribeToBlockNumber(for chain: ChainModel) {
        blockNumberSubscription = subscribeToBlockNumber(for: chain.chainId)
    }

    private func subscribeToMetadata(for option: GovernanceSelectedOption) {
        metadataProvider = subscribeGovernanceMetadata(for: option)

        if metadataProvider == nil {
            presenter?.didReceiveReferendumsMetadata([])
        }
    }

    func fetchBlockTimeWithVoting() {
        fetchBlockTime(forceVotingFetch: true)
    }

    func fetchBlockTime(forceVotingFetch: Bool = false) {
        clear(cancellable: &blockTimeCancellable)

        let blockTimeWrapper = blockTimeOperationFactory.createBlockTimeOperation(
            from: runtimeService,
            blockTimeEstimationService: blockTimeService
        )

        blockTimeWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.blockTimeCancellable === blockTimeWrapper else {
                    return
                }

                self?.blockTimeCancellable = nil

                do {
                    let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()

                    if forceVotingFetch {
                        self?.provideOffchainVoting(for: blockTime)
                    }

                    self?.presenter?.didReceiveBlockTime(blockTime)
                } catch {
                    self?.presenter?.didReceiveError(.blockTimeFetchFailed(error))
                }
            }
        }

        blockTimeCancellable = blockTimeWrapper

        operationQueue.addOperations(blockTimeWrapper.allOperations, waitUntilFinished: false)
    }

    private func provideOffchainVotingIfNeeded() {
        if offchainVotingCancellable == nil, currentBlockNumber != nil {
            fetchBlockTimeWithVoting()
        }
    }

    private func provideOffchainVoting(for blockTime: BlockTime) {
        switch dataFetchOption {
        case .allTimes:
            provideOffchainVoting(from: nil)
        case let .recent(days):
            guard
                let activityBlockNumber = currentBlockNumber?.blockBackInDays(
                    days,
                    blockTime: blockTime
                ) else {
                return
            }

            provideOffchainVoting(from: activityBlockNumber)
        }
    }

    private func provideOffchainVoting(from blockNumber: BlockNumber?) {
        clear(cancellable: &offchainVotingCancellable)

        let votingWrapper = fetchFactory.createVotedReferendaWrapper(
            for: .init(address: address, blockNumber: blockNumber),
            connection: connection,
            runtimeService: runtimeService
        )

        votingWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.offchainVotingCancellable === votingWrapper else {
                    return
                }

                self?.offchainVotingCancellable = nil

                do {
                    let voting = try votingWrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveOffchainVoting(voting)
                } catch {
                    self?.presenter?.didReceiveError(.offchainVotingFetchFailed(error))
                }
            }
        }

        offchainVotingCancellable = votingWrapper

        operationQueue.addOperations(votingWrapper.allOperations, waitUntilFinished: false)
    }
}

extension DelegateVotedReferendaInteractor: DelegateVotedReferendaInteractorInputProtocol {
    func setup() {
        subscribeToBlockNumber(for: governanceOption.chain)
        subscribeToMetadata(for: governanceOption)
    }

    func retryBlockTime() {
        fetchBlockTime(forceVotingFetch: true)
    }

    func retryOffchainVotingFetch() {
        provideOffchainVotingIfNeeded()
    }

    func remakeSubscription() {
        subscribeToBlockNumber(for: governanceOption.chain)
        subscribeToMetadata(for: governanceOption)
    }
}

extension DelegateVotedReferendaInteractor: GovMetadataLocalStorageSubscriber, GovMetadataLocalStorageHandler {
    func handleGovernanceMetadataPreview(
        result: Result<[DataProviderChange<ReferendumMetadataLocal>], Error>,
        option _: GovernanceSelectedOption
    ) {
        switch result {
        case let .success(changes):
            presenter?.didReceiveReferendumsMetadata(changes)
        case let .failure(error):
            presenter?.didReceiveError(.metadataSubscriptionFailed(error))
        }
    }
}

extension DelegateVotedReferendaInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(blockNumber):
            if let blockNumber = blockNumber {
                let optLastBlockNumber = currentBlockNumber
                currentBlockNumber = blockNumber

                let forceVotingFetch = optLastBlockNumber.map { !blockNumber.isNext(to: $0) } ?? true

                fetchBlockTime(forceVotingFetch: forceVotingFetch)
                presenter?.didReceiveBlockNumber(blockNumber)
            }
        case let .failure(error):
            presenter?.didReceiveError(.blockNumberSubscriptionFailed(error))
        }
    }
}
