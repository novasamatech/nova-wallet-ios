import Foundation
import BigInt
import SubstrateSdk
import RobinHood

final class ParaStakingRewardCalculatorService {
    static let queueLabelPrefix = "com.novawallet.parastk.rewcalculator"

    private struct PendingRequest {
        let resultClosure: (ParaStakingRewardCalculatorEngineProtocol) -> Void
        let queue: DispatchQueue?
    }

    private struct Snapshot {
        let totalStaked: BigUInt
        let totalIssuance: BigUInt
        let inflation: ParachainStaking.InflationConfig
        let parachainBond: ParachainStaking.ParachainBondConfig
    }

    let syncQueue = DispatchQueue(
        label: "\(queueLabelPrefix).\(UUID().uuidString)",
        qos: .userInitiated
    )

    private var isActive: Bool = false
    private var snapshot: Snapshot?

    private var totalIssuance: BigUInt?
    private var totalStaked: BigUInt?
    private var inflationConfig: ParachainStaking.InflationConfig?
    private var parachainBondConfig: ParachainStaking.ParachainBondConfig?

    private var totalIssuanceProvider: AnyDataProvider<DecodedBigUInt>?
    private var roundProvider: AnyDataProvider<ParachainStaking.DecodedRoundInfo>?
    private var inflationProvider: AnyDataProvider<ParachainStaking.DecodedInflationConfig>?
    private var parachainBondProvider: AnyDataProvider<ParachainStaking.DecodedParachainBondConfig>?

    var totalStakedService: StorageItemSyncService<StringScaleMapper<BigUInt>>?

    private var pendingRequests: [PendingRequest] = []

    let chainId: ChainModel.Id
    let collatorsService: ParachainStakingCollatorServiceProtocol
    let providerFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let operationQueue: OperationQueue
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeCodingService: RuntimeProviderProtocol
    let logger: LoggerProtocol
    let assetPrecision: Int16

    init(
        chainId: ChainModel.Id,
        collatorsService: ParachainStakingCollatorServiceProtocol,
        providerFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeCodingService: RuntimeProviderProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        operationQueue: OperationQueue,
        assetPrecision: Int16,
        logger: LoggerProtocol
    ) {
        self.chainId = chainId
        self.collatorsService = collatorsService
        self.providerFactory = providerFactory
        self.connection = connection
        self.runtimeCodingService = runtimeCodingService
        self.repositoryFactory = repositoryFactory
        self.operationQueue = operationQueue
        self.assetPrecision = assetPrecision
        self.logger = logger
    }

    // MARK: - Private

    func didUpdateTotalStaked(_ totalStaked: BigUInt) {
        self.totalStaked = totalStaked
        didUpdateShapshotParam()
    }

    private func didUpdateShapshotParam() {
        if
            let totalIssuance = totalIssuance,
            let totalStaked = totalStaked,
            let inflationConfig = inflationConfig,
            let parachainBondConfig = parachainBondConfig {
            let snapshot = Snapshot(
                totalStaked: totalStaked,
                totalIssuance: totalIssuance,
                inflation: inflationConfig,
                parachainBond: parachainBondConfig
            )

            self.snapshot = snapshot

            notifyPendingClosures(with: snapshot)
        }
    }

    private func fetchInfoFactory(
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (ParaStakingRewardCalculatorEngineProtocol) -> Void
    ) {
        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request, assetPrecision: assetPrecision)
        } else {
            pendingRequests.append(request)
        }
    }

    private func deliver(
        snapshot: Snapshot,
        to request: PendingRequest,
        assetPrecision: Int16
    ) {
        let collatorsOperation = collatorsService.fetchInfoOperation()

        let mapOperation = ClosureOperation<ParaStakingRewardCalculatorEngineProtocol> {
            let selectedCollators = try collatorsOperation.extractNoCancellableResultData()

            return ParaStakingRewardCalculatorEngine(
                totalIssuance: snapshot.totalIssuance,
                totalStaked: snapshot.totalStaked,
                inflation: snapshot.inflation,
                parachainBond: snapshot.parachainBond,
                selectedCollators: selectedCollators,
                assetPrecision: assetPrecision
            )
        }

        mapOperation.addDependency(collatorsOperation)

        mapOperation.completionBlock = {
            dispatchInQueueWhenPossible(request.queue) {
                switch mapOperation.result {
                case let .success(calculator):
                    request.resultClosure(calculator)
                case let .failure(error):
                    self.logger.error("Era stakers info fetch error: \(error)")
                case .none:
                    self.logger.warning("Era stakers info fetch cancelled")
                }
            }
        }

        let operations = [collatorsOperation, mapOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    private func notifyPendingClosures(with snapshot: Snapshot) {
        logger.debug("Attempt fulfill pendings \(pendingRequests.count)")

        guard !pendingRequests.isEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = []

        requests.forEach {
            deliver(snapshot: snapshot, to: $0, assetPrecision: assetPrecision)
        }

        logger.debug("Fulfilled pendings")
    }

    private func subscribe() {
        do {
            try subscribeTotalIssuance()
            try subscribeRound()
            try subscribeInflationConfig()
            try subscribeParachainBondConfig()
        } catch {
            logger.error("Can't make subscription")
        }
    }

    private func unsubscribe() {
        totalIssuanceProvider?.removeObserver(self)
        totalIssuanceProvider = nil

        roundProvider?.removeObserver(self)
        roundProvider = nil

        inflationProvider?.removeObserver(self)
        inflationProvider = nil

        parachainBondProvider?.removeObserver(self)
        parachainBondProvider = nil

        totalStakedService?.throttle()
        totalStakedService = nil
    }
}

extension ParaStakingRewardCalculatorService {
    private func subscribeTotalIssuance() throws {
        guard totalIssuanceProvider == nil else {
            return
        }

        totalIssuanceProvider = try providerFactory.getTotalIssuanceProvider(for: chainId)

        let updateClosure: ([DataProviderChange<DecodedBigUInt>]) -> Void = { [weak self] changes in
            self?.totalIssuance = changes.reduceToLastChange()?.item?.value
            self?.didUpdateShapshotParam()
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger.error("Did receive error: \(error)")
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        totalIssuanceProvider?.addObserver(
            self,
            deliverOn: syncQueue,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func subscribeRound() throws {
        guard roundProvider == nil else {
            return
        }

        roundProvider = try providerFactory.getRoundProvider(for: chainId)

        let updateClosure: ([DataProviderChange<ParachainStaking.DecodedRoundInfo>]) -> Void

        updateClosure = { [weak self] changes in
            if let round = changes.reduceToLastChange()?.item {
                self?.updateStaked(for: round)
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger.error("Did receive error: \(error)")
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        roundProvider?.addObserver(
            self,
            deliverOn: syncQueue,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func subscribeInflationConfig() throws {
        guard inflationProvider == nil else {
            return
        }

        inflationProvider = try providerFactory.getInflationProvider(for: chainId)

        let updateClosure: ([DataProviderChange<ParachainStaking.DecodedInflationConfig>]) -> Void

        updateClosure = { [weak self] changes in
            self?.inflationConfig = changes.reduceToLastChange()?.item
            self?.didUpdateShapshotParam()
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger.error("Did receive error: \(error)")
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        inflationProvider?.addObserver(
            self,
            deliverOn: syncQueue,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func subscribeParachainBondConfig() throws {
        guard parachainBondProvider == nil else {
            return
        }

        parachainBondProvider = try providerFactory.getParachainBondProvider(for: chainId)

        let updateClosure: ([DataProviderChange<ParachainStaking.DecodedParachainBondConfig>]) -> Void

        updateClosure = { [weak self] changes in
            self?.parachainBondConfig = changes.reduceToLastChange()?.item
            self?.didUpdateShapshotParam()
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger.error("Did receive error: \(error)")
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        parachainBondProvider?.addObserver(
            self,
            deliverOn: syncQueue,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }
}

extension ParaStakingRewardCalculatorService: ParaStakingRewardCalculatorServiceProtocol {
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
            guard !self.isActive else {
                return
            }

            self.isActive = false

            self.unsubscribe()
        }
    }

    func fetchCalculatorOperation() -> BaseOperation<ParaStakingRewardCalculatorEngineProtocol> {
        ClosureOperation {
            var fetchedInfo: ParaStakingRewardCalculatorEngineProtocol?

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
