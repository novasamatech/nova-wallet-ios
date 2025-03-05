import Foundation
import BigInt
import SubstrateSdk
import Operation_iOS

struct ParaStkRewardParamsSnapshot {
    let totalStaked: BigUInt
    let totalIssuance: BigUInt
    let inflation: ParachainStaking.InflationConfig
    let inflationDistribution: ParachainStaking.InflationDistributionPercent
}

class BaseParaStakingRewardCalculatoService: CollatorStakingRewardService<ParaStkRewardParamsSnapshot> {
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
        eventCenter: EventCenterProtocol,
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

        let syncQueue = DispatchQueue(
            label: "com.novawallet.parastk.rewcalculator.\(UUID().uuidString)",
            qos: .userInitiated
        )

        inflationDistributionProvider = ParaStakingInflationDistrProvider(
            chainId: chainId,
            runtimeService: runtimeCodingService,
            providerFactory: providerFactory,
            operationQueue: operationQueue,
            syncQueue: syncQueue
        )

        super.init(eventCenter: eventCenter, logger: logger, syncQueue: syncQueue)
    }

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
            let snapshot = ParaStkRewardParamsSnapshot(
                totalStaked: totalStaked,
                totalIssuance: totalIssuance,
                inflation: inflationConfig,
                inflationDistribution: inflationDistribution
            )

            updateSnapshotAndNotify(snapshot, chainId: chainId)
        }
    }

    // MARK: Subsclass

    override func start() {
        do {
            try subscribeTotalIssuance()
            try subscribeInflationConfig()
            try subscribeInflationDistribution()
            updateTotalStaked()
        } catch {
            logger.error("Can't make subscription")
        }
    }

    override func stop() {
        totalIssuanceProvider?.removeObserver(self)
        totalIssuanceProvider = nil

        inflationProvider?.removeObserver(self)
        inflationProvider = nil

        inflationDistributionProvider.throttle()

        totalStakeCancellable.cancel()
    }

    override func deliver(snapshot: ParaStkRewardParamsSnapshot, to pendingRequest: PendingRequest) {
        deliver(snapshot: snapshot, to: pendingRequest, assetPrecision: assetPrecision)
    }
}

private extension BaseParaStakingRewardCalculatoService {
    func deliver(
        snapshot: ParaStkRewardParamsSnapshot,
        to request: PendingRequest,
        assetPrecision: Int16
    ) {
        let collatorsOperation = collatorsService.fetchInfoOperation()

        let mapOperation = ClosureOperation<CollatorStakingRewardCalculatorEngineProtocol> {
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

    func subscribeTotalIssuance() throws {
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

    func subscribeInflationConfig() throws {
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

    func subscribeInflationDistribution() throws {
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
