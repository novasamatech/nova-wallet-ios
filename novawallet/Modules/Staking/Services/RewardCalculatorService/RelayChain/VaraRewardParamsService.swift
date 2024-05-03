import Foundation
import SubstrateSdk
import BigInt
import RobinHood

final class VaraRewardParamsService: BaseSyncService {
    struct InflationConfig: Decodable {
        let inflation: Decimal
    }

    let connection: JSONRPCEngine
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue

    private var cancellableStore = CancellableCallStore()

    private var stateObserver = Observable<BigUInt?>(state: nil)

    init(
        connection: JSONRPCEngine,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.connection = connection
        self.runtimeCodingService = runtimeCodingService
        self.operationQueue = operationQueue
    }

    override func performSyncUp() {
        let operation = JSONRPCOperation<String, InflationConfig>(
            engine: connection,
            method: "stakingRewards_inflationInfo",
            parameters: nil,
            timeout: 30
        )

        executeCancellable(
            wrapper: CompoundOperationWrapper(targetOperation: operation),
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: nil,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(model):
                self?.completeImmediate(nil)
                self?.stateObserver.state = model.inflation.toSubstrateAmount(precision: 0)
            case let .failure(error):
                self?.completeImmediate(error)
            }
        }
    }

    override func stopSyncUp() {
        cancellableStore.cancel()
    }
}

extension VaraRewardParamsService: RewardCalculatorParamsServiceProtocol {
    func subcribe(
        using notificationQueue: DispatchQueue,
        notificationClosure: @escaping (Result<RewardCalculatorParams, Error>) -> Void
    ) {
        mutex.lock()

        stateObserver.addObserver(with: self, queue: notificationQueue) { _, newInflation in
            guard let newInflation else {
                return
            }

            notificationClosure(.success(.vara(inflation: newInflation)))
        }

        mutex.unlock()

        setup()
    }

    func unsubscribe() {
        mutex.lock()

        stateObserver.removeObserver(by: self)

        mutex.unlock()

        throttle()
    }
}
