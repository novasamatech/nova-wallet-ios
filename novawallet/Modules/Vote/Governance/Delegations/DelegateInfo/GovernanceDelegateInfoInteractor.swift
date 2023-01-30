import UIKit
import SubstrateSdk
import RobinHood

final class GovernanceDelegateInfoInteractor {
    weak var presenter: GovernanceDelegateInfoInteractorOutputProtocol?

    let delegate: AccountId
    let chain: ChainModel
    let lastVotedDays: Int
    let fetchBlockTreshold: BlockNumber
    let detailsOperationFactory: GovernanceDelegateStatsFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
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
        delegate: AccountId,
        chain: ChainModel,
        lastVotedDays: Int,
        fetchBlockTreshold: BlockNumber,
        detailsOperationFactory: GovernanceDelegateStatsFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        metadataProvider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]>,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.delegate = delegate
        self.chain = chain
        self.lastVotedDays = lastVotedDays
        self.fetchBlockTreshold = fetchBlockTreshold
        self.detailsOperationFactory = detailsOperationFactory
        self.connection = connection
        self.runtimeService = runtimeService
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.metadataProvider = metadataProvider
        self.identityOperationFactory = identityOperationFactory
        self.blockTimeService = blockTimeService
        self.blockTimeFactory = blockTimeFactory
        self.operationQueue = operationQueue
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

    private func estimateStatsBlockNumber() -> BlockNumber? {
        guard let blockNumber = currentBlockNumber, let blockTime = currentBlockTime, blockTime > 0 else {
            return nil
        }

        let blocksInPast = BlockNumber(TimeInterval(lastVotedDays).secondsFromDays / TimeInterval(blockTime).seconds)

        guard blockNumber > blocksInPast else {
            return nil
        }

        return blockNumber - blocksInPast
    }

    private func fetchDetailsIfNeeded() {
        do {
            guard let activityBlockNumber = estimateStatsBlockNumber() else {
                return
            }

            if
                let lastUsedBlockNumber = lastUsedBlockNumber,
                activityBlockNumber > lastUsedBlockNumber,
                activityBlockNumber - lastUsedBlockNumber < fetchBlockTreshold {
                return
            }

            lastUsedBlockNumber = activityBlockNumber

            let delegateAddress = try delegate.toAddress(using: chain.chainFormat)

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
        subscribeMetadata(for: delegate)
        provideIdentity(for: delegate)
    }

    func refreshDetails() {
        lastUsedBlockNumber = nil
        fetchDetailsIfNeeded()
    }

    func remakeSubscriptions() {
        subscribeBlockNumber()

        clearMetadataSubscription()
        subscribeMetadata(for: delegate)
    }

    func refreshIdentity() {
        provideIdentity(for: delegate)
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
