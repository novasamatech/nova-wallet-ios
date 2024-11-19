import Foundation
import SubstrateSdk
import BigInt
import Operation_iOS

enum PolkadotRewardParamsServiceError: Error {
    case runtimeApiNotFound
}

struct RuntimeApiInflationPrediction: Decodable, Equatable {
    struct NextMint: Decodable, Equatable {
        let items: [BigUInt]

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()

            items = try container.decode([StringScaleMapper<BigUInt>].self).map(\.value)
        }
    }

    @StringCodable var inflation: BigUInt
    let nextMint: NextMint
}

final class PolkadotRewardParamsService: BaseSyncService {
    let connection: JSONRPCEngine
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let stateCallFactory: StateCallRequestFactoryProtocol
    let operationQueue: OperationQueue

    private var cancellableStore = CancellableCallStore()

    private var stateObserver = Observable<RuntimeApiInflationPrediction?>(state: nil)

    init(
        connection: JSONRPCEngine,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        stateCallFactory: StateCallRequestFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.connection = connection
        self.runtimeCodingService = runtimeCodingService
        self.stateCallFactory = stateCallFactory
        self.operationQueue = operationQueue
    }

    override func performSyncUp() {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

        let fetchWrapper = OperationCombiningService<RuntimeApiInflationPrediction>.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            guard let runtimeApi = codingFactory.metadata.getRuntimeApiMethod(
                for: "Inflation",
                methodName: "experimental_inflation_prediction_info"
            ) else {
                throw PolkadotRewardParamsServiceError.runtimeApiNotFound
            }

            return self.stateCallFactory.createWrapper(
                for: runtimeApi.callName,
                paramsClosure: nil,
                codingFactoryClosure: { codingFactory },
                connection: self.connection,
                queryType: String(runtimeApi.method.output)
            )
        }

        fetchWrapper.addDependency(operations: [codingFactoryOperation])

        let totalWrapper = fetchWrapper.insertingHead(operations: [codingFactoryOperation])

        executeCancellable(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: nil,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(model):
                self?.completeImmediate(nil)
                self?.stateObserver.state = model
            case let .failure(error):
                self?.completeImmediate(error)
            }
        }
    }

    override func stopSyncUp() {
        cancellableStore.cancel()
    }
}

extension PolkadotRewardParamsService: RewardCalculatorParamsServiceProtocol {
    func subcribe(
        using notificationQueue: DispatchQueue,
        notificationClosure: @escaping (Result<RewardCalculatorParams, Error>) -> Void
    ) {
        mutex.lock()

        stateObserver.addObserver(with: self, queue: notificationQueue) { _, newPrediction in
            guard let newPrediction else {
                return
            }

            notificationClosure(.success(.polkadot(inflationPrediction: newPrediction)))
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
