import Foundation
import SubstrateSdk
import BigInt
import Operation_iOS

final class PolkadotRewardParamsService: BaseSyncService {
    let connection: JSONRPCEngine
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let stakersRewardFactory: PolkadotStakersRewardFactoryProtocol
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
        stakersRewardFactory = PolkadotStakersRewardFactory(operationQueue: operationQueue)
        self.operationQueue = operationQueue
    }

    override func performSyncUp() {
        cancellableStore.cancel()

        let wrapper = stakersRewardFactory.createStakersRewardWrapper(
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
            case let .success(reward):
                self?.completeImmediate(nil)
                self?.stateObserver.state = reward
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

        stateObserver.addObserver(with: self, queue: notificationQueue) { _, newReward in
            guard let newReward else {
                return
            }

            notificationClosure(.success(.polkadot(stakersEraReward: newReward)))
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
