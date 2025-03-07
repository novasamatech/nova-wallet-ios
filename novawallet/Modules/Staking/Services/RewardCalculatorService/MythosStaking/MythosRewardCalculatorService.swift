import Foundation
import Operation_iOS
import BigInt

struct MythosRewardsParamsSnapshot {
    let minStake: Balance
    let collatorRewardsPercentage: Decimal
    let extraReward: Balance
}

final class MythosRewardCalculatorService: CollatorStakingRewardService<MythosRewardsParamsSnapshot> {
    let chainAsset: ChainAsset
    let stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol
    let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let runtimeService: RuntimeProviderProtocol
    let collatorService: MythosCollatorServiceProtocol
    let operationQueue: OperationQueue

    private var minStakeProvider: AnyDataProvider<DecodedBigUInt>?
    private var currentSessionProvider: AnyDataProvider<DecodedU32>?
    private var collatorRewardsPercentageProvider: AnyDataProvider<DecodedPercent>?
    private var extraRewardsProvider: AnyDataProvider<DecodedBigUInt>?

    private var minStake: Balance?
    private var collatorRewardsPercentage: Percent?
    private var extraReward: Balance?

    init(
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol,
        blockTimeOperationFactory: BlockTimeOperationFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        runtimeService: RuntimeProviderProtocol,
        collatorService: MythosCollatorServiceProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.chainAsset = chainAsset
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.blockTimeOperationFactory = blockTimeOperationFactory
        self.blockTimeService = blockTimeService
        self.runtimeService = runtimeService
        self.collatorService = collatorService
        self.operationQueue = operationQueue

        let syncQueue = DispatchQueue(
            label: "com.novawallet.mythos.rewcalculator.\(UUID().uuidString)",
            qos: .userInitiated
        )

        super.init(eventCenter: eventCenter, logger: logger, syncQueue: syncQueue)
    }

    override func start() {
        clearSubscriptions()
        setupSubscriptions()
    }

    override func stop() {
        clearSubscriptions()
    }

    override func deliver(snapshot: MythosRewardsParamsSnapshot, to request: PendingRequest) {
        deliver(snapshot: snapshot, to: request, chainAsset: chainAsset)
    }
}

extension MythosRewardCalculatorService: AnyProviderAutoCleaning {}

private extension MythosRewardCalculatorService {
    private func createBlockTimeWrapper() -> CompoundOperationWrapper<BlockTime> {
        // To prevent differences with the indexer use fixed block time if available
        if let blockTime = chainAsset.chain.defaultBlockTimeMillis {
            return .createWithResult(blockTime)
        }

        return blockTimeOperationFactory.createBlockTimeOperation(
            from: runtimeService,
            blockTimeEstimationService: blockTimeService
        )
    }

    func deliver(
        snapshot: MythosRewardsParamsSnapshot,
        to request: PendingRequest,
        chainAsset: ChainAsset
    ) {
        let collatorsOperation = collatorService.fetchInfoOperation()

        let blockTimeWrapper = createBlockTimeWrapper()

        let mappingOperation = ClosureOperation<CollatorStakingRewardCalculatorEngineProtocol> {
            let collators = try collatorsOperation.extractNoCancellableResultData()
            let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()

            let params = MythosRewardCalculatorEngine.Params(
                perBlockRewards: snapshot.extraReward,
                blockTime: blockTime,
                collatorComission: snapshot.collatorRewardsPercentage,
                collators: collators,
                minStake: snapshot.minStake,
                asset: chainAsset
            )

            return MythosRewardCalculatorEngine(params: params)
        }

        mappingOperation.addDependency(collatorsOperation)
        mappingOperation.addDependency(blockTimeWrapper.targetOperation)

        let totalWrapper = blockTimeWrapper
            .insertingHead(operations: [collatorsOperation])
            .insertingTail(operation: mappingOperation)

        execute(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: request.queue
        ) { [weak self] result in
            switch result {
            case let .success(engine):
                request.resultClosure(engine)
            case let .failure(error):
                self?.logger.error("Engine fetch error: \(error)")
            }
        }
    }

    func clearSubscriptions() {
        clear(dataProvider: &minStakeProvider)
        clear(dataProvider: &currentSessionProvider)
        clear(dataProvider: &collatorRewardsPercentageProvider)
        clear(dataProvider: &extraRewardsProvider)
    }

    func setupSubscriptions() {
        minStakeProvider = subscribeToMinStake(
            for: chainAsset.chain.chainId,
            callbackQueue: syncQueue
        )

        currentSessionProvider = subscribeToCurrentSession(
            for: chainAsset.chain.chainId,
            callbackQueue: syncQueue
        )

        collatorRewardsPercentageProvider = subscribeToCollatorRewardsPercentage(
            for: chainAsset.chain.chainId,
            callbackQueue: syncQueue
        )

        extraRewardsProvider = subscribeToExtraReward(
            for: chainAsset.chain.chainId,
            callbackQueue: syncQueue
        )
    }

    func didUpdateShapshotParam() {
        if
            let minStake,
            let collatorPercentage = collatorRewardsPercentage?.percentToFraction(),
            let extraReward {
            let snapshot = MythosRewardsParamsSnapshot(
                minStake: minStake,
                collatorRewardsPercentage: collatorPercentage,
                extraReward: extraReward
            )

            updateSnapshotAndNotify(
                snapshot,
                chainId: chainAsset.chainAssetId.chainId
            )
        }
    }
}

extension MythosRewardCalculatorService: MythosStakingLocalStorageSubscriber, MythosStakingLocalStorageHandler {
    func handleMinStake(
        result: Result<Balance?, Error>,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(minStake):
            self.minStake = minStake
            didUpdateShapshotParam()
        case let .failure(error):
            logger.error("Min stake subscription failed: \(error)")
        }
    }

    func handleCurrentSession(
        result: Result<SessionIndex?, Error>,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case .success:
            // triggers an update when new session starts
            didUpdateShapshotParam()
        case let .failure(error):
            logger.error("Session subscription failed: \(error)")
        }
    }

    func handleCollatorRewardsPercentage(
        result: Result<Percent?, Error>,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(percent):
            collatorRewardsPercentage = percent
            didUpdateShapshotParam()
        case let .failure(error):
            logger.error("Collator reward percentage subscription failed: \(error)")
        }
    }

    func handleExtraReward(
        result: Result<Balance?, Error>,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(extraReward):
            self.extraReward = extraReward
            didUpdateShapshotParam()
        case let .failure(error):
            logger.error("Extra reward subscription failed: \(error)")
        }
    }
}
