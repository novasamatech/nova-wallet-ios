import Foundation
import Operation_iOS
import SubstrateSdk

final class AuraTimelineParamsOperationFactory {
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    let sessionPeriodOperationFactory: StakingSessionPeriodOperationFactoryProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol

    init(
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeOperationFactory: BlockTimeOperationFactoryProtocol,
        sessionPeriodOperationFactory: StakingSessionPeriodOperationFactoryProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol
    ) {
        self.chainId = chainId
        self.chainRegistry = chainRegistry
        self.blockTimeService = blockTimeService
        self.blockTimeOperationFactory = blockTimeOperationFactory
        self.sessionPeriodOperationFactory = sessionPeriodOperationFactory
        self.storageRequestFactory = storageRequestFactory
    }
}

extension AuraTimelineParamsOperationFactory: RelayStkTimelineParamsOperationFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<RelayStkTimelineParams> {
        do {
            let chain = try chainRegistry.getTimelineChainOrError(for: chainId)
            let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)
            let connection = try chainRegistry.getConnectionOrError(for: chain.chainId)

            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let sessionLengthOperation: BaseOperation<SessionIndex> = sessionPeriodOperationFactory.createOperation(
                dependingOn: codingFactoryOperation
            )

            sessionLengthOperation.addDependency(codingFactoryOperation)

            let blockTimeWrapper = blockTimeOperationFactory.createBlockTimeOperation(
                from: runtimeService,
                blockTimeEstimationService: blockTimeService
            )

            let sessionIndexWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<SessionIndex>>> =
                storageRequestFactory.queryItem(
                    engine: connection,
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    storagePath: SessionPallet.currentSessionIndexPath
                )

            sessionIndexWrapper.addDependency(operations: [codingFactoryOperation])

            let blockNumberWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<BlockNumber>>> =
                storageRequestFactory.queryItem(
                    engine: connection,
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    storagePath: SystemPallet.blockNumberPath
                )

            blockNumberWrapper.addDependency(operations: [codingFactoryOperation])

            let mergeOperation = ClosureOperation<RelayStkTimelineParams> {
                let sessionLength = try sessionLengthOperation.extractNoCancellableResultData()
                let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()
                let currentSessionResponse = try sessionIndexWrapper.targetOperation.extractNoCancellableResultData()
                let currentSessionIndex = try currentSessionResponse.ensureValue()
                let blockNumber = try blockNumberWrapper.targetOperation.extractNoCancellableResultData().ensureValue()

                return RelayStkTimelineParams(
                    sessionLength: sessionLength,
                    currentSessionIndex: currentSessionIndex.value,
                    currentEpochIndex: EpochIndex(currentSessionIndex.value),
                    currentSlot: Slot(blockNumber.value),
                    genesisSlot: 0,
                    blockTime: Moment(blockTime)
                )
            }

            mergeOperation.addDependency(sessionLengthOperation)
            mergeOperation.addDependency(blockTimeWrapper.targetOperation)
            mergeOperation.addDependency(sessionIndexWrapper.targetOperation)
            mergeOperation.addDependency(blockNumberWrapper.targetOperation)

            return blockNumberWrapper
                .insertingHead(operations: sessionIndexWrapper.allOperations)
                .insertingHead(operations: blockTimeWrapper.allOperations)
                .insertingHead(operations: [codingFactoryOperation, sessionLengthOperation])
                .insertingTail(operation: mergeOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
