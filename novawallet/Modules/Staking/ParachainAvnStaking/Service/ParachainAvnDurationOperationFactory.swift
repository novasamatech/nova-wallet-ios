import Foundation
import Operation_iOS
import SubstrateSdk

/// Duration operation factory for Energy Web X staking.
///
/// EWX differences from Moonbeam:
/// - Round info is at storage item "Era" (not "Round")
/// - Unbond delay is a storage item "Delay" (u32 eras), not a
///   runtime constant like Moonbeam's "DelegationBondLessDelay"
final class ParachainAvnDurationOperationFactory: ParaStkDurationOperationFactoryProtocol {
    let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol

    init(
        storageRequestFactory: StorageRequestFactoryProtocol,
        blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    ) {
        self.storageRequestFactory = storageRequestFactory
        self.blockTimeOperationFactory = blockTimeOperationFactory
    }

    func createDurationOperation(
        from runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        blockTimeEstimationService: BlockTimeEstimationServiceProtocol
    ) -> CompoundOperationWrapper<ParachainStakingDuration> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let blockTimeWrapper = blockTimeOperationFactory.createBlockTimeOperation(
            from: runtimeService,
            blockTimeEstimationService: blockTimeEstimationService
        )

        // Query Era storage (EWX name for round info — same type as RoundInfo)
        let eraWrapper: CompoundOperationWrapper<StorageResponse<ParachainStaking.RoundInfo>>
        eraWrapper = storageRequestFactory.queryItem(
            engine: connection,
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: ParachainAvn.eraPath
        )
        eraWrapper.addDependency(operations: [codingFactoryOperation])

        // Query Delay storage (u32 — number of eras for unbond delay)
        let delayWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<UInt32>>>
        delayWrapper = storageRequestFactory.queryItem(
            engine: connection,
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: ParachainAvn.delayPath
        )
        delayWrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<ParachainStakingDuration> {
            let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()

            let eraLength = try eraWrapper.targetOperation
                .extractNoCancellableResultData().value?.length
                ?? ParachainAvnStakingConstants.fallbackEraBlocks

            let unbondDelayEras = try delayWrapper.targetOperation
                .extractNoCancellableResultData().value?.value
                ?? ParachainAvnStakingConstants.fallbackUnbondDelayEras

            let blockTimeInterval = TimeInterval(blockTime).seconds
            let roundDuration = TimeInterval(eraLength) * blockTimeInterval
            let unstakingDuration = TimeInterval(unbondDelayEras) * roundDuration

            return ParachainStakingDuration(
                block: blockTimeInterval,
                round: roundDuration,
                unstaking: unstakingDuration
            )
        }

        let dependencies = [codingFactoryOperation]
            + eraWrapper.allOperations
            + delayWrapper.allOperations
            + blockTimeWrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }
}
