import Foundation
import BigInt
import SubstrateSdk
import Operation_iOS

/// Snapshot of the values needed to compute EWX staking APR.
struct ParachainAvnRewardSnapshot {
    let annualApr: Decimal
    let commission: Decimal
    let totalStaked: BigUInt
}

/// Reward calculator service for Energy Web X.
///
/// Fetches the `Growth` storage for the latest completed growth period
/// and computes APR from
/// `(totalStakerReward / totalStakeAccumulated) * (365 / numberOfAccumulations)`.
/// Falls back to a 2M EWT annual-rewards estimate divided by total
/// staked when Growth data isn't available (e.g. before period 1).
final class ParachainAvnRewardCalculatorService: CollatorStakingRewardService<ParachainAvnRewardSnapshot> {
    /// EWX runs one era per day, so a year = 365 accumulation eras.
    private static let erasPerYear: Decimal = 365
    /// Last-resort APR estimate when Growth storage hasn't accumulated yet.
    private static let fallbackAnnualRewardsEwt: Decimal = 2_000_000
    /// Last-resort commission when `DefaultCollatorCommission` can't be decoded.
    private static let fallbackCommissionPerbill: BigUInt = 100_000_000

    let chainId: ChainModel.Id
    let collatorsService: ParachainStakingCollatorServiceProtocol
    let connection: JSONRPCEngine
    let runtimeCodingService: RuntimeProviderProtocol
    let operationQueue: OperationQueue
    let assetPrecision: Int16

    private var fetchCancellable = CancellableCallStore()

    init(
        chainId: ChainModel.Id,
        collatorsService: ParachainStakingCollatorServiceProtocol,
        connection: JSONRPCEngine,
        runtimeCodingService: RuntimeProviderProtocol,
        operationQueue: OperationQueue,
        assetPrecision: Int16,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.chainId = chainId
        self.collatorsService = collatorsService
        self.connection = connection
        self.runtimeCodingService = runtimeCodingService
        self.operationQueue = operationQueue
        self.assetPrecision = assetPrecision

        let syncQueue = DispatchQueue(
            label: "com.novawallet.parachainavn.rewcalculator.\(UUID().uuidString)",
            qos: .userInitiated
        )

        super.init(eventCenter: eventCenter, logger: logger, syncQueue: syncQueue)
    }

    override func start() {
        fetchGrowthData()
    }

    override func stop() {
        fetchCancellable.cancel()
    }

    override func deliver(snapshot: ParachainAvnRewardSnapshot, to pendingRequest: PendingRequest) {
        let collatorsOperation = collatorsService.fetchInfoOperation()

        let assetPrecision = self.assetPrecision

        let mapOperation = ClosureOperation<CollatorStakingRewardCalculatorEngineProtocol> {
            let selectedCollators = try collatorsOperation.extractNoCancellableResultData()

            return ParachainAvnRewardCalculatorEngine(
                annualApr: snapshot.annualApr,
                commission: snapshot.commission,
                totalStakedAmount: snapshot.totalStaked,
                selectedCollators: selectedCollators,
                assetPrecision: assetPrecision
            )
        }

        mapOperation.addDependency(collatorsOperation)

        mapOperation.completionBlock = {
            dispatchInQueueWhenPossible(pendingRequest.queue) {
                switch mapOperation.result {
                case let .success(calculator):
                    pendingRequest.resultClosure(calculator)
                case let .failure(error):
                    self.logger.error("ParachainAvn reward calculator error: \(error)")
                case .none:
                    self.logger.warning("ParachainAvn reward calculator cancelled")
                }
            }
        }

        operationQueue.addOperations([collatorsOperation, mapOperation], waitUntilFinished: false)
    }

    // MARK: - Private

    private func fetchGrowthData() {
        fetchCancellable.cancel()

        let operationManager = OperationManager(operationQueue: operationQueue)

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager,
            timeout: JSONRPCTimeout.hour
        )

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

        let totalWrapper = makeQueryWrapper(
            requestFactory: requestFactory,
            codingFactoryOperation: codingFactoryOperation,
            storagePath: ParachainAvn.totalPath,
            type: StringScaleMapper<BigUInt>.self
        )
        let commissionWrapper = makeQueryWrapper(
            requestFactory: requestFactory,
            codingFactoryOperation: codingFactoryOperation,
            storagePath: ParachainAvn.defaultCollatorCommissionPath,
            type: ParachainAvn.CommissionSetting.self
        )
        let growthPeriodWrapper = makeQueryWrapper(
            requestFactory: requestFactory,
            codingFactoryOperation: codingFactoryOperation,
            storagePath: ParachainAvn.growthPeriodPath,
            type: ParachainAvn.GrowthPeriod.self
        )
        let growthInfoWrapper = makeGrowthInfoWrapper(
            requestFactory: requestFactory,
            operationManager: operationManager,
            codingFactoryOperation: codingFactoryOperation,
            growthPeriodWrapper: growthPeriodWrapper
        )

        let mergeOperation = makeMergeOperation(
            totalWrapper: totalWrapper,
            commissionWrapper: commissionWrapper,
            growthInfoWrapper: growthInfoWrapper
        )

        mergeOperation.addDependency(totalWrapper.targetOperation)
        mergeOperation.addDependency(commissionWrapper.targetOperation)
        mergeOperation.addDependency(growthInfoWrapper.targetOperation)

        let allDependencies = [codingFactoryOperation]
            + totalWrapper.allOperations
            + commissionWrapper.allOperations
            + growthPeriodWrapper.allOperations
            + growthInfoWrapper.allOperations
        let fullWrapper = CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: allDependencies
        )

        executeCancellable(
            wrapper: fullWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: fetchCancellable,
            runningCallbackIn: syncQueue
        ) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(snapshot):
                self.updateSnapshotAndNotify(snapshot, chainId: self.chainId)
            case let .failure(error):
                self.logger.error("ParachainAvn growth data fetch error: \(error)")
            }
        }
    }

    private func makeQueryWrapper<T: Decodable>(
        requestFactory: StorageRequestFactoryProtocol,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        storagePath: StorageCodingPath,
        type _: T.Type
    ) -> CompoundOperationWrapper<StorageResponse<T>> {
        let wrapper: CompoundOperationWrapper<StorageResponse<T>> = requestFactory.queryItem(
            engine: connection,
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: storagePath,
            at: nil
        )
        wrapper.addDependency(operations: [codingFactoryOperation])
        return wrapper
    }

    /// Query `Growth(period.index - 1)` once `GrowthPeriod` is resolved.
    /// We use the previous (completed) period because the current one is
    /// still accumulating and would understate APR.
    private func makeGrowthInfoWrapper(
        requestFactory: StorageRequestFactoryProtocol,
        operationManager: OperationManagerProtocol,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        growthPeriodWrapper: CompoundOperationWrapper<StorageResponse<ParachainAvn.GrowthPeriod>>
    ) -> CompoundOperationWrapper<[StorageResponse<ParachainAvn.GrowthInfo>]> {
        let connection = self.connection
        let wrapper: CompoundOperationWrapper<[StorageResponse<ParachainAvn.GrowthInfo>]>
        wrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: operationManager
        ) {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let periodResponse = try growthPeriodWrapper.targetOperation.extractNoCancellableResultData()

            guard let period = periodResponse.value, period.index > 0 else {
                let emptyOp = ClosureOperation<[StorageResponse<ParachainAvn.GrowthInfo>]> { [] }
                return CompoundOperationWrapper(targetOperation: emptyOp)
            }

            let prevIndex = period.index - 1

            return requestFactory.queryItems(
                engine: connection,
                keyParams: { [StringScaleMapper(value: UInt32(prevIndex))] },
                factory: { codingFactory },
                storagePath: ParachainAvn.growthPath,
                at: nil
            )
        }
        wrapper.addDependency(operations: [
            growthPeriodWrapper.targetOperation,
            codingFactoryOperation
        ])
        return wrapper
    }

    private func makeMergeOperation(
        totalWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<BigUInt>>>,
        commissionWrapper: CompoundOperationWrapper<StorageResponse<ParachainAvn.CommissionSetting>>,
        growthInfoWrapper: CompoundOperationWrapper<[StorageResponse<ParachainAvn.GrowthInfo>]>
    ) -> ClosureOperation<ParachainAvnRewardSnapshot> {
        let assetPrecision = self.assetPrecision
        return ClosureOperation<ParachainAvnRewardSnapshot> {
            let totalResponse = try? totalWrapper.targetOperation.extractNoCancellableResultData()
            let totalStaked = totalResponse?.value?.value ?? 0

            let commissionResponse = try? commissionWrapper.targetOperation.extractNoCancellableResultData()
            let commissionPerbill = commissionResponse?.value?.current ?? Self.fallbackCommissionPerbill
            let commission = Decimal.fromSubstratePerbill(value: commissionPerbill) ?? Decimal(0.10)

            // Use 0 (not 1) so a conversion failure surfaces as 0% APR via
            // the `totalStakedDecimal > 0` guard inside `computeApr`. With
            // a `?? 1` fallback a precision misconfig would compute APR as
            // `2_000_000 / 1 = 200_000_000%`.
            let totalStakedDecimal = Decimal.fromSubstrateAmount(
                totalStaked, precision: assetPrecision
            ) ?? 0

            let grossApr = Self.computeApr(
                growthInfoResponses: try? growthInfoWrapper.targetOperation.extractNoCancellableResultData(),
                totalStakedDecimal: totalStakedDecimal,
                assetPrecision: assetPrecision
            )

            return ParachainAvnRewardSnapshot(
                annualApr: grossApr,
                commission: commission,
                totalStaked: totalStaked
            )
        }
    }

    private static func computeApr(
        growthInfoResponses: [StorageResponse<ParachainAvn.GrowthInfo>]?,
        totalStakedDecimal: Decimal,
        assetPrecision: Int16
    ) -> Decimal {
        let fallback: Decimal = totalStakedDecimal > 0
            ? fallbackAnnualRewardsEwt / totalStakedDecimal
            : 0

        guard
            let growthInfo = growthInfoResponses?.first?.value,
            growthInfo.numberOfAccumulations > 0,
            growthInfo.totalStakeAccumulated > 0
        else {
            return fallback
        }

        let stakerRewardDecimal = Decimal.fromSubstrateAmount(
            growthInfo.totalStakerReward, precision: assetPrecision
        ) ?? 0
        let stakeAccumulatedDecimal = Decimal.fromSubstrateAmount(
            growthInfo.totalStakeAccumulated, precision: assetPrecision
        ) ?? 0

        guard stakeAccumulatedDecimal > 0 else { return fallback }

        let perPeriod = stakerRewardDecimal / stakeAccumulatedDecimal
        let accumulations = Decimal(growthInfo.numberOfAccumulations)
        return accumulations > 0 ? perPeriod * (erasPerYear / accumulations) : fallback
    }
}
