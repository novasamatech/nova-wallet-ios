import UIKit
import Operation_iOS
import SubstrateSdk

final class DelegateVotedReferendaInteractor: AnyProviderAutoCleaning, AnyCancellableCleaning {
    weak var presenter: DelegateVotedReferendaInteractorOutputProtocol?

    let address: AccountAddress
    let governanceOption: GovernanceSelectedOption
    let connection: JSONRPCEngine
    let runtimeService: RuntimeProviderProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let timepointThresholdService: TimepointThresholdServiceProtocol
    let timelineService: ChainTimelineFacadeProtocol
    let govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol
    let fetchFactory: DelegateVotedReferendaOperationFactoryProtocol
    let dataFetchOption: DelegateVotedReferendaOption
    let operationQueue: OperationQueue

    private var currentBlockNumber: BlockNumber?
    private var currentThreshold: TimepointThreshold?

    private(set) var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?
    private(set) var metadataProvider: StreamableProvider<ReferendumMetadataLocal>?

    private let referendumsCallStore = CancellableCallStore()
    private let offchainVotingCallStore = CancellableCallStore()
    private let blocktimeCallStore = CancellableCallStore()

    init(
        address: AccountAddress,
        governanceOption: GovernanceSelectedOption,
        connection: JSONRPCEngine,
        runtimeService: RuntimeProviderProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        timepointThresholdService: TimepointThresholdServiceProtocol,
        timelineService: ChainTimelineFacadeProtocol,
        govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol,
        fetchFactory: DelegateVotedReferendaOperationFactoryProtocol,
        dataFetchOption: DelegateVotedReferendaOption,
        operationQueue: OperationQueue
    ) {
        self.address = address
        self.governanceOption = governanceOption
        self.connection = connection
        self.runtimeService = runtimeService
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.timepointThresholdService = timepointThresholdService
        self.timelineService = timelineService
        self.govMetadataLocalSubscriptionFactory = govMetadataLocalSubscriptionFactory
        self.fetchFactory = fetchFactory
        self.dataFetchOption = dataFetchOption
        self.operationQueue = operationQueue
    }

    deinit {
        referendumsCallStore.cancel()
        offchainVotingCallStore.cancel()
        blocktimeCallStore.cancel()
    }
}

// MARK: - Private

private extension DelegateVotedReferendaInteractor {
    func subscribeTimepointThreshold() {
        timepointThresholdService.remove(observer: self)

        timepointThresholdService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
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

            provideOffchainVoting()
        }
    }

    func subscribeToMetadata(for option: GovernanceSelectedOption) {
        clear(streamableProvider: &metadataProvider)
        metadataProvider = subscribeGovernanceMetadata(for: option)

        guard metadataProvider == nil else { return }

        presenter?.didReceiveReferendumsMetadata([])
    }

    func subscribeToBlockNumber() {
        clear(dataProvider: &blockNumberSubscription)
        blockNumberSubscription = subscribeToBlockNumber(for: timelineService.timelineChainId)
    }

    func provideOffchainVotingIfNeeded() {
        guard !offchainVotingCallStore.hasCall, currentThreshold != nil else {
            return
        }

        provideOffchainVoting()
    }

    func provideOffchainVoting() {
        switch dataFetchOption {
        case .allTimes:
            provideOffchainVoting(for: nil)
        case let .recent(days):
            let threshold = currentThreshold?.backIn(seconds: TimeInterval(days).secondsFromDays)

            provideOffchainVoting(for: threshold)
        }
    }

    func provideOffchainVoting(for timepointThreshold: TimepointThreshold?) {
        let votingWrapper = fetchFactory.createVotedReferendaWrapper(
            for: .init(address: address, timepointThreshold: timepointThreshold),
            connection: connection,
            runtimeService: runtimeService
        )

        executeCancellable(
            wrapper: votingWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: offchainVotingCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(voting):
                self?.presenter?.didReceiveOffchainVoting(voting)
            case let .failure(error):
                self?.presenter?.didReceiveError(.offchainVotingFetchFailed(error))
            }
        }
    }

    func fetchBlockTime() {
        let blockTimeWrapper = timelineService.createBlockTimeOperation()

        executeCancellable(
            wrapper: blockTimeWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: blocktimeCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(blockTime):
                self?.presenter?.didReceiveBlockTime(blockTime)
            case let .failure(error):
                self?.presenter?.didReceiveError(.blockTimeFetchFailed(error))
            }
        }
    }
}

// MARK: - DelegateVotedReferendaInteractorInputProtocol

extension DelegateVotedReferendaInteractor: DelegateVotedReferendaInteractorInputProtocol {
    func retryBlockTime() {
        fetchBlockTime()
    }

    func setup() {
        subscribeToBlockNumber()
        subscribeTimepointThreshold()
        subscribeToMetadata(for: governanceOption)
    }

    func retryTimepointThreshold() {
        provideOffchainVoting()
    }

    func retryOffchainVotingFetch() {
        provideOffchainVotingIfNeeded()
    }

    func remakeSubscription() {
        subscribeToMetadata(for: governanceOption)
        subscribeToBlockNumber()
    }
}

// MARK: - GovMetadataLocalStorageSubscriber

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

// MARK: - GeneralLocalStorageSubscriber

extension DelegateVotedReferendaInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(blockNumber):
            if let blockNumber = blockNumber {
                currentBlockNumber = blockNumber

                fetchBlockTime()
                presenter?.didReceiveBlockNumber(blockNumber)
            }
        case let .failure(error):
            presenter?.didReceiveError(.blockNumberSubscriptionFailed(error))
        }
    }
}
