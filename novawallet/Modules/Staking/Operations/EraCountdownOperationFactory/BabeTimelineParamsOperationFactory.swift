import Foundation
import Operation_iOS
import SubstrateSdk

final class BabeTimelineParamsOperationFactory {
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol

    init(
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol
    ) {
        self.chainId = chainId
        self.chainRegistry = chainRegistry
        self.storageRequestFactory = storageRequestFactory
    }
}

extension BabeTimelineParamsOperationFactory: RelayStkTimelineParamsOperationFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<RelayStkTimelineParams> {
        do {
            let chain = try chainRegistry.getTimelineChainOrError(for: chainId)
            let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)
            let connection = try chainRegistry.getConnectionOrError(for: chain.chainId)

            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let sessionLengthWrapper: CompoundOperationWrapper<SessionIndex> = PrimitiveConstantOperation.wrapper(
                for: BabePallet.sessionLengthPath,
                runtimeService: runtimeService
            )

            let blockTimeWrapper: CompoundOperationWrapper<Moment> = PrimitiveConstantOperation.wrapper(
                for: BabePallet.blockTimePath,
                runtimeService: runtimeService
            )

            let sessionIndexWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<SessionIndex>>> =
                storageRequestFactory.queryItem(
                    engine: connection,
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    storagePath: SessionPallet.currentSessionIndexPath
                )

            sessionIndexWrapper.addDependency(operations: [codingFactoryOperation])

            let currentSlotWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<Slot>>> =
                storageRequestFactory.queryItem(
                    engine: connection,
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    storagePath: BabePallet.currentSlotPath
                )

            currentSlotWrapper.addDependency(operations: [codingFactoryOperation])

            let genesisSlotWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<Slot>>> =
                storageRequestFactory.queryItem(
                    engine: connection,
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    storagePath: BabePallet.genesisSlotPath
                )

            genesisSlotWrapper.addDependency(operations: [codingFactoryOperation])

            let currentEpochWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<Slot>>> =
                storageRequestFactory.queryItem(
                    engine: connection,
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    storagePath: BabePallet.currentEpochPath
                )

            currentEpochWrapper.addDependency(operations: [codingFactoryOperation])

            let mergeOperation = ClosureOperation<RelayStkTimelineParams> {
                let sessionLength = try sessionLengthWrapper.targetOperation.extractNoCancellableResultData()
                let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()
                let sessionIndex = try sessionIndexWrapper.targetOperation.extractNoCancellableResultData()
                    .ensureValue()

                let currentSlot = try currentSlotWrapper.targetOperation.extractNoCancellableResultData().ensureValue()
                let genesisSlot = try genesisSlotWrapper.targetOperation.extractNoCancellableResultData().ensureValue()

                let currentEpoch = try currentEpochWrapper.targetOperation.extractNoCancellableResultData()
                    .ensureValue()

                return RelayStkTimelineParams(
                    sessionLength: sessionLength,
                    currentSessionIndex: sessionLength,
                    currentEpochIndex: currentEpoch.value,
                    currentSlot: currentSlot.value,
                    genesisSlot: genesisSlot.value,
                    blockTime: blockTime
                )
            }

            mergeOperation.addDependency(sessionLengthWrapper.targetOperation)
            mergeOperation.addDependency(blockTimeWrapper.targetOperation)
            mergeOperation.addDependency(sessionIndexWrapper.targetOperation)
            mergeOperation.addDependency(currentSlotWrapper.targetOperation)
            mergeOperation.addDependency(genesisSlotWrapper.targetOperation)
            mergeOperation.addDependency(currentEpochWrapper.targetOperation)

            return currentEpochWrapper
                .insertingHead(operations: genesisSlotWrapper.allOperations)
                .insertingHead(operations: currentSlotWrapper.allOperations)
                .insertingHead(operations: sessionIndexWrapper.allOperations)
                .insertingHead(operations: blockTimeWrapper.allOperations)
                .insertingHead(operations: sessionLengthWrapper.allOperations)
                .insertingHead(operations: [codingFactoryOperation])
                .insertingTail(operation: mergeOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
