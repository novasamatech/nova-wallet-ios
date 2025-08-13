import Foundation
import SubstrateSdk
import Operation_iOS

protocol EraCountdownOperationFactoryProtocol {
    func fetchCountdownOperationWrapper() -> CompoundOperationWrapper<EraCountdown>
}

final class RelayStkEraCountdownOperationFactory {
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let timelineOperationFactory: RelayStkTimelineParamsOperationFactoryProtocol
    let eraStartOperationFactory: RelayStkEraStartOperationFactoryProtocol

    init(
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        timelineOperationFactory: RelayStkTimelineParamsOperationFactoryProtocol,
        eraStartOperationFactory: RelayStkEraStartOperationFactoryProtocol
    ) {
        self.chainId = chainId
        self.chainRegistry = chainRegistry
        self.storageRequestFactory = storageRequestFactory
        self.timelineOperationFactory = timelineOperationFactory
        self.eraStartOperationFactory = eraStartOperationFactory
    }
}

extension RelayStkEraCountdownOperationFactory: EraCountdownOperationFactoryProtocol {
    func fetchCountdownOperationWrapper() -> CompoundOperationWrapper<EraCountdown> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chainId)
            let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: chainId)

            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let eraLengthWrapper: CompoundOperationWrapper<SessionIndex> = PrimitiveConstantOperation.wrapper(
                for: Staking.eraLengthPath,
                runtimeService: runtimeService
            )

            let activeEraWrapper: CompoundOperationWrapper<StorageResponse<Staking.ActiveEraInfo>> =
                storageRequestFactory.queryItem(
                    engine: connection,
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    storagePath: Staking.activeEra
                )

            activeEraWrapper.addDependency(operations: [codingFactoryOperation])

            let currentEraWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<Staking.EraIndex>>> =
                storageRequestFactory.queryItem(
                    engine: connection,
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    storagePath: Staking.currentEra
                )

            currentEraWrapper.addDependency(operations: [codingFactoryOperation])

            let eraStartSessionWrapper = eraStartOperationFactory.createEraStartSessionIndexWrapper(
                activeEraClosure: {
                    try activeEraWrapper.targetOperation.extractNoCancellableResultData().ensureValue()
                },
                chainId: chainId
            )

            eraStartSessionWrapper.addDependency(wrapper: activeEraWrapper)

            let timelineWrapper = timelineOperationFactory.createWrapper()

            let mergeOperation = ClosureOperation<EraCountdown> {
                let eraLength = try eraLengthWrapper.targetOperation.extractNoCancellableResultData()
                let activeEra = try activeEraWrapper.targetOperation.extractNoCancellableResultData().ensureValue()
                let currentEra = try currentEraWrapper.targetOperation.extractNoCancellableResultData().ensureValue()
                let eraStartSessionIndex = try eraStartSessionWrapper.targetOperation.extractNoCancellableResultData()
                let timeline = try timelineWrapper.targetOperation.extractNoCancellableResultData()

                return EraCountdown(
                    activeEra: activeEra.index,
                    currentEra: currentEra.value,
                    eraLength: eraLength,
                    sessionLength: timeline.sessionLength,
                    activeEraStartSessionIndex: eraStartSessionIndex,
                    currentSessionIndex: timeline.currentSessionIndex,
                    currentEpochIndex: timeline.currentEpochIndex,
                    currentSlot: timeline.currentSlot,
                    genesisSlot: timeline.genesisSlot,
                    blockCreationTime: timeline.blockTime,
                    eraDelayInBlocks: timeline.eraDelayInBlocks,
                    createdAtDate: Date()
                )
            }

            mergeOperation.addDependency(eraLengthWrapper.targetOperation)
            mergeOperation.addDependency(activeEraWrapper.targetOperation)
            mergeOperation.addDependency(currentEraWrapper.targetOperation)
            mergeOperation.addDependency(eraStartSessionWrapper.targetOperation)
            mergeOperation.addDependency(timelineWrapper.targetOperation)

            return timelineWrapper
                .insertingHead(operations: eraStartSessionWrapper.allOperations)
                .insertingHead(operations: currentEraWrapper.allOperations)
                .insertingHead(operations: activeEraWrapper.allOperations)
                .insertingHead(operations: eraLengthWrapper.allOperations)
                .insertingHead(operations: [codingFactoryOperation])
                .insertingTail(operation: mergeOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
