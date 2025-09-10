import Foundation
import Operation_iOS

protocol TimepointThresholdStoreProtocol {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        closure: @escaping Observable<TimepointThreshold?>.StateChangeClosure
    )
    func remove(observer: AnyObject)
    func reset()
}

final class TimepointThresholdStore: BaseObservableStateStore<TimepointThreshold>, AnyProviderAutoCleaning {
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol

    private let chain: ChainModel
    private let chainRegistry: ChainRegistryProtocol
    private let estimationService: BlockTimeEstimationServiceProtocol
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue

    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?

    private var observers: [Observable<RemoteState?>.ObserverWrapper] {
        stateObservable.observers
    }

    init(
        chain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        estimationService: BlockTimeEstimationServiceProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue
    ) {
        self.chain = chain
        self.chainRegistry = chainRegistry
        self.estimationService = estimationService
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue

        super.init(logger: Logger.shared)

        setup()
    }
}

// MARK: - Private

private extension TimepointThresholdStore {
    func setup() {
        guard chain.separateTimelineChain else {
            blockNumberProvider = subscribeToBlockNumber(for: chain.chainId)
            return
        }

        updateState(with: Int64(Date().timeIntervalSince1970))
    }

    func throttle() {
        clear(dataProvider: &blockNumberProvider)
    }

    func updateState(with timestamp: Int64) {
        stateObservable.state = .timestamp(timestamp)
    }

    func updateState(with blockNumber: BlockNumber) {
        do {
            let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)

            let blockTimeWrapper = BlockTimeOperationFactory(chain: chain).createBlockTimeOperation(
                from: runtimeService,
                blockTimeEstimationService: estimationService
            )

            execute(
                wrapper: blockTimeWrapper,
                inOperationQueue: operationQueue,
                runningCallbackIn: workingQueue
            ) { [weak self] result in
                switch result {
                case let .success(blockTime):
                    self?.stateObservable.state = .block(blockNumber: blockNumber, blockTime: blockTime)
                case let .failure(error):
                    self?.logger.error("Did receive block time error: \(error)")
                }
            }
        } catch {
            logger.error("Did receive runtime provider fetch error: \(error)")
        }
    }
}

// MARK: - GeneralLocalStorageSubscriber

extension TimepointThresholdStore: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(blockNumber):
            guard let blockNumber else { return }
            updateState(with: blockNumber)
        case let .failure(error):
            logger.error("Did receive block number error: \(error)")
        }

        guard observers.isEmpty else { return }

        throttle()
    }
}

// MARK: - TimepointThresholdStoreProtocol

extension TimepointThresholdStore: TimepointThresholdStoreProtocol {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        closure: @escaping Observable<TimepointThreshold?>.StateChangeClosure
    ) {
        if observers.isEmpty {
            setup()
        }

        add(
            observer: observer,
            sendStateOnSubscription: sendStateOnSubscription,
            queue: workingQueue,
            closure: closure
        )
    }
}
