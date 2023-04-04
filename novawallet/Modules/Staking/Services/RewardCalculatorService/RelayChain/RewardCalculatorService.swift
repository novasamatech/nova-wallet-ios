import Foundation
import RobinHood
import SubstrateSdk
import BigInt

enum RewardCalculatorServiceError: Error {
    case timedOut
    case unexpectedInfo
}

final class RewardCalculatorService {
    static let queueLabelPrefix = "com.novawallet.rewcalculator"

    private struct PendingRequest {
        let resultClosure: (RewardCalculatorEngineProtocol) -> Void
        let queue: DispatchQueue?
    }

    private struct Snapshot {
        let totalIssuance: BigUInt
        let params: RewardCalculatorParams
    }

    private let syncQueue = DispatchQueue(
        label: "\(queueLabelPrefix).\(UUID().uuidString)",
        qos: .userInitiated
    )

    private var isActive: Bool = false
    private var totalIssuance: BigUInt?
    private var params: RewardCalculatorParams?

    private var totalIssuanceDataProvider: AnyDataProvider<DecodedBigUInt>?
    private var paramsService: RewardCalculatorParamsServiceProtocol?
    private var pendingRequests: [PendingRequest] = []

    let chainId: ChainModel.Id
    let eraValidatorsService: EraValidatorServiceProtocol
    let logger: LoggerProtocol?
    let operationManager: OperationManagerProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let storageFacade: StorageFacadeProtocol
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let stakingDurationFactory: StakingDurationOperationFactoryProtocol
    let rewardCalculatorFactory: RewardCalculatorEngineFactoryProtocol
    let rewardCalculatorParamsFactory: RewardCalculatorParamsServiceFactoryProtocol

    init(
        chainId: ChainModel.Id,
        rewardCalculatorFactory: RewardCalculatorEngineFactoryProtocol,
        rewardCalculatorParamsFactory: RewardCalculatorParamsServiceFactoryProtocol,
        eraValidatorsService: EraValidatorServiceProtocol,
        operationManager: OperationManagerProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        stakingDurationFactory: StakingDurationOperationFactoryProtocol,
        storageFacade: StorageFacadeProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.chainId = chainId
        self.rewardCalculatorFactory = rewardCalculatorFactory
        self.rewardCalculatorParamsFactory = rewardCalculatorParamsFactory
        self.storageFacade = storageFacade
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.operationManager = operationManager
        self.eraValidatorsService = eraValidatorsService
        self.stakingDurationFactory = stakingDurationFactory
        self.runtimeCodingService = runtimeCodingService
        self.logger = logger
    }

    // MARK: - Private

    private func fetchInfoFactory(
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (RewardCalculatorEngineProtocol) -> Void
    ) {
        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let totalIssuance = totalIssuance, let params = params {
            deliver(
                snapshot: .init(totalIssuance: totalIssuance, params: params),
                to: request,
                rewardCalculatorFactory: rewardCalculatorFactory
            )
        } else {
            pendingRequests.append(request)
        }
    }

    private func deliver(
        snapshot: Snapshot,
        to request: PendingRequest,
        rewardCalculatorFactory: RewardCalculatorEngineFactoryProtocol
    ) {
        let durationWrapper = stakingDurationFactory.createDurationOperation(
            from: runtimeCodingService
        )

        let eraOperation = eraValidatorsService.fetchInfoOperation()

        let mapOperation = ClosureOperation<RewardCalculatorEngineProtocol> {
            let eraStakersInfo = try eraOperation.extractNoCancellableResultData()
            let stakingDuration = try durationWrapper.targetOperation.extractNoCancellableResultData()

            return rewardCalculatorFactory.createRewardCalculator(
                for: snapshot.totalIssuance,
                params: snapshot.params,
                validators: eraStakersInfo.validators,
                eraDurationInSeconds: stakingDuration.era
            )
        }

        mapOperation.addDependency(durationWrapper.targetOperation)
        mapOperation.addDependency(eraOperation)

        mapOperation.completionBlock = {
            dispatchInQueueWhenPossible(request.queue) {
                switch mapOperation.result {
                case let .success(calculator):
                    request.resultClosure(calculator)
                case let .failure(error):
                    self.logger?.error("Era stakers info fetch error: \(error)")
                case .none:
                    self.logger?.warning("Era stakers info fetch cancelled")
                }
            }
        }

        operationManager.enqueue(
            operations: durationWrapper.allOperations + [eraOperation, mapOperation],
            in: .transient
        )
    }

    private func notifyPendingClosuresIfReady() {
        guard let totalIssuance = totalIssuance, let params = params else {
            return
        }

        let snapshot = Snapshot(totalIssuance: totalIssuance, params: params)

        logger?.debug("Attempt fulfill pendings \(pendingRequests.count)")

        guard !pendingRequests.isEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = []

        requests.forEach {
            deliver(
                snapshot: snapshot,
                to: $0,
                rewardCalculatorFactory: rewardCalculatorFactory
            )
        }

        logger?.debug("Fulfilled pendings")
    }

    private func subscribe() {
        totalIssuanceDataProvider = subscribeTotalIssuance(for: chainId, callbackQueue: syncQueue)

        paramsService = rewardCalculatorParamsFactory.createRewardCalculatorParamsService()
        paramsService?.subcribe(using: syncQueue) { [weak self] result in
            switch result {
            case let .success(params):
                self?.params = params
                self?.notifyPendingClosuresIfReady()
            case let .failure(error):
                self?.logger?.error("Can't fetch params: \(error)")
            }
        }
    }

    private func unsubscribe() {
        totalIssuanceDataProvider?.removeObserver(self)
        totalIssuanceDataProvider = nil

        paramsService?.unsubscribe()
        paramsService = nil
    }
}

extension RewardCalculatorService: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleTotalIssuance(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(totalIssuance):
            self.totalIssuance = totalIssuance
            notifyPendingClosuresIfReady()
        case let .failure(error):
            logger?.error("Did receive total issuance decoding error: \(error)")
        }
    }
}

extension RewardCalculatorService: RewardCalculatorServiceProtocol {
    func setup() {
        syncQueue.async {
            guard !self.isActive else {
                return
            }

            self.isActive = true

            self.subscribe()
        }
    }

    func throttle() {
        syncQueue.async {
            guard self.isActive else {
                return
            }

            self.isActive = false

            self.unsubscribe()
        }
    }

    func fetchCalculatorOperation() -> BaseOperation<RewardCalculatorEngineProtocol> {
        ClosureOperation {
            var fetchedInfo: RewardCalculatorEngineProtocol?

            let semaphore = DispatchSemaphore(value: 0)

            self.syncQueue.async {
                self.fetchInfoFactory(runCompletionIn: nil) { [weak semaphore] info in
                    fetchedInfo = info
                    semaphore?.signal()
                }
            }

            semaphore.wait()

            guard let info = fetchedInfo else {
                throw RewardCalculatorServiceError.unexpectedInfo
            }

            return info
        }
    }
}
