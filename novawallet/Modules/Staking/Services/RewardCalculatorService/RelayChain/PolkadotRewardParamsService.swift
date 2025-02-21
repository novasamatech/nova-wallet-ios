import Foundation
import SubstrateSdk
import BigInt
import Operation_iOS

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
    let inflationFetchFactory: PolkadotInflationPredictionFactoryProtocol
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
        inflationFetchFactory = PolkadotInflationPredictionFactory(
            stateCallFactory: stateCallFactory,
            operationQueue: operationQueue
        )
        self.operationQueue = operationQueue
    }

    override func performSyncUp() {
        cancellableStore.cancel()

        let wrapper = inflationFetchFactory.createPredictionWrapper(
            for: connection,
            runtimeProvider: runtimeCodingService
        )

        executeCancellable(
            wrapper: wrapper,
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
