import Foundation
import Operation_iOS

protocol TimepointThresholdServiceProtocol: AnyObject {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        closure: @escaping Observable<TimepointThreshold?>.StateChangeClosure
    )
    func remove(observer: AnyObject)
    func reset()
    func setup()
}

final class TimepointThresholdService: BaseObservableStateStore<TimepointThreshold>, AnyProviderAutoCleaning {
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol

    private let chain: ChainModel
    private let chainRegistry: ChainRegistryProtocol
    private let estimationService: BlockTimeEstimationServiceProtocol
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue

    private let callStore = CancellableCallStore()

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
    }
}

// MARK: - Private

private extension TimepointThresholdService {
    func updateState(with blockNumber: BlockNumber) {
        do {
            let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)

            let blockTimeWrapper = BlockTimeOperationFactory(chain: chain).createBlockTimeOperation(
                from: runtimeService,
                blockTimeEstimationService: estimationService
            )

            executeCancellable(
                wrapper: blockTimeWrapper,
                inOperationQueue: operationQueue,
                backingCallIn: callStore,
                runningCallbackIn: workingQueue,
                mutex: mutex
            ) { [weak self] result in
                switch result {
                case let .success(blockTime):
                    self?.stateObservable.state = TimepointThreshold(
                        type: .block(blockNumber: blockNumber, blockTime: blockTime)
                    )
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

extension TimepointThresholdService: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(blockNumber):
            guard let blockNumber else { return }
            mutex.lock()
            updateState(with: blockNumber)
            mutex.unlock()
        case let .failure(error):
            logger.error("Did receive block number error: \(error)")
        }
    }
}

// MARK: - TimepointThresholdServiceProtocol

extension TimepointThresholdService: TimepointThresholdServiceProtocol {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        closure: @escaping Observable<TimepointThreshold?>.StateChangeClosure
    ) {
        add(
            observer: observer,
            sendStateOnSubscription: sendStateOnSubscription,
            queue: workingQueue,
            closure: closure
        )
    }

    func setup() {
        mutex.lock()
        defer { mutex.unlock() }

        let alreadySetUp: Bool = stateObservable.state != nil || blockNumberProvider != nil

        guard !alreadySetUp else {
            return
        }

        guard chain.separateTimelineChain else {
            blockNumberProvider = subscribeToBlockNumber(for: chain.chainId)
            return
        }

        stateObservable.state = TimepointThreshold(type: .timestamp)
    }
}
