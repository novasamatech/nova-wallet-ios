import Foundation
import BigInt
import SubstrateSdk
import Operation_iOS

class BaseParaStakingRewardCalculatoService {
    static let queueLabelPrefix = "com.novawallet.parastk.rewcalculator"

    struct PendingRequest {
        let resultClosure: (ParaStakingRewardCalculatorEngineProtocol) -> Void
        let queue: DispatchQueue?
    }

    struct Snapshot {
        let totalStaked: BigUInt
        let totalIssuance: BigUInt
        let inflation: ParachainStaking.InflationConfig
        let inflationDistribution: ParachainStaking.InflationDistributionPercent
    }

    let syncQueue = DispatchQueue(
        label: "\(queueLabelPrefix).\(UUID().uuidString)",
        qos: .userInitiated
    )

    private var isActive: Bool = false
    private var snapshot: Snapshot?

    private(set) var totalIssuance: BigUInt?
    private(set) var totalStaked: BigUInt?
    private(set) var inflationConfig: ParachainStaking.InflationConfig?
    private(set) var inflationDistribution: ParachainStaking.InflationDistributionPercent?

    private var totalIssuanceProvider: AnyDataProvider<DecodedBigUInt>?
    private var inflationProvider: AnyDataProvider<ParachainStaking.DecodedInflationConfig>?

    private(set) var totalStakeCancellable = CancellableCallStore()

    private var pendingRequests: [UUID: PendingRequest] = [:]

    let chainId: ChainModel.Id
    let collatorsService: ParachainStakingCollatorServiceProtocol
    let providerFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let inflationDistributionProvider: ParaStakingInflationDistrProviding
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

        inflationDistributionProvider = ParaStakingInflationDistrProvider(
            chainId: chainId,
            runtimeService: runtimeCodingService,
            providerFactory: providerFactory,
            operationQueue: operationQueue,
            syncQueue: syncQueue
        )
    }

    // MARK: - Private

    func didUpdateTotalStaked(_ totalStaked: BigUInt) {
        self.totalStaked = totalStaked
        didUpdateShapshotParam()
    }

    func didUpdateShapshotParam() {
        if
            let totalIssuance,
            let totalStaked,
            let inflationConfig,
            let inflationDistribution {
            let snapshot = Snapshot(
                totalStaked: totalStaked,
                totalIssuance: totalIssuance,
                inflation: inflationConfig,
                inflationDistribution: inflationDistribution
            )

            updateSnapshotAndNotify(snapshot)
        }
    }

    func updateSnapshotAndNotify(_ snapshot: Snapshot) {
        self.snapshot = snapshot

        notifyPendingClosures(with: snapshot)
    }

    private func fetchInfoFactory(
        assigning requestId: UUID,
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (ParaStakingRewardCalculatorEngineProtocol) -> Void
    ) {
        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request, assetPrecision: assetPrecision)
        } else {
            pendingRequests[requestId] = request
        }
    }

    private func cancel(for requestId: UUID) {
        pendingRequests[requestId] = nil
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
                inflationDistribution: snapshot.inflationDistribution,
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
        pendingRequests = [:]

        requests.values.forEach {
            deliver(snapshot: snapshot, to: $0, assetPrecision: assetPrecision)
        }

        logger.debug("Fulfilled pendings")
    }

    func subscribe() {
        do {
            try subscribeTotalIssuance()
            try subscribeInflationConfig()
            try subscribeInflationDistribution()
            updateTotalStaked()
        } catch {
            logger.error("Can't make subscription")
        }
    }

    func unsubscribe() {
        totalIssuanceProvider?.removeObserver(self)
        totalIssuanceProvider = nil

        inflationProvider?.removeObserver(self)
        inflationProvider = nil

        inflationDistributionProvider.throttle()

        totalStakeCancellable.cancel()
    }
}

extension BaseParaStakingRewardCalculatoService {
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

    private func subscribeInflationDistribution() throws {
        inflationDistributionProvider.setup { [weak self] result in
            switch result {
            case let .success(inflationDistribution):
                self?.inflationDistribution = inflationDistribution
            case let .failure(error):
                self?.logger.error("Did receive error: \(error)")
            }
        }
    }
}

extension BaseParaStakingRewardCalculatoService: ParaStakingRewardCalculatorServiceProtocol {
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

    func fetchCalculatorOperation() -> BaseOperation<ParaStakingRewardCalculatorEngineProtocol> {
        let requestId = UUID()

        return AsyncClosureOperation(
            operationClosure: { closure in
                self.syncQueue.async {
                    self.fetchInfoFactory(assigning: requestId, runCompletionIn: nil) { info in
                        closure(.success(info))
                    }
                }
            },
            cancelationClosure: {
                self.syncQueue.async {
                    self.cancel(for: requestId)
                }
            }
        )
    }
}
