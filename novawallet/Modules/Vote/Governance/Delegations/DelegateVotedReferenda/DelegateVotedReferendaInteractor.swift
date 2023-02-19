import UIKit
import RobinHood
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
    let fetchBlockTreshold: BlockNumber
    let operationQueue: OperationQueue

    private var lastUsedBlockNumber: BlockNumber?
    private var currentBlockNumber: BlockNumber?
    private var currentBlockTime: BlockTime?

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
        fetchBlockTreshold: BlockNumber,
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
        self.fetchBlockTreshold = fetchBlockTreshold
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

    func provideBlockTime() {
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
                    self?.currentBlockTime = blockTime
                    self?.provideOffchainVotingIfNeeded()
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
        if offchainVotingCancellable == nil {
            provideOffchainVoting()
        }
    }

    private func provideOffchainVoting() {
        switch dataFetchOption {
        case .allTimes:
            if
                let lastUsedBlockNumber = lastUsedBlockNumber,
                let currentBlockNumber = currentBlockNumber,
                currentBlockNumber > lastUsedBlockNumber,
                currentBlockNumber - lastUsedBlockNumber < fetchBlockTreshold {
                return
            }

            lastUsedBlockNumber = currentBlockNumber

            provideOffchainVoting(from: nil)
        case let .recent(days):
            guard
                let activityBlockNumber = currentBlockNumber?.blockBackInDays(
                    days,
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

            provideOffchainVoting(from: activityBlockNumber)
        }
    }

    private func provideOffchainVoting(from blockNumber: BlockNumber?) {
        clear(cancellable: &offchainVotingCancellable)

        let votingWrapper = fetchFactory.createVotedReferendaWrapper(
            for: .init(address: address, blockNumber: blockNumber),
            chain: governanceOption.chain,
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
        provideBlockTime()
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
                currentBlockNumber = blockNumber
                provideBlockTime()
                presenter?.didReceiveBlockNumber(blockNumber)
            }
        case let .failure(error): break
            presenter?.didReceiveError(.blockNumberSubscriptionFailed(error))
        }
    }
}
