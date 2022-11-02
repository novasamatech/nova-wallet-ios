import Foundation
import RobinHood
import SubstrateSdk

struct ParachainStakingDuration {
    let block: TimeInterval
    let round: TimeInterval
    let unstaking: TimeInterval
}

protocol ParaStkDurationOperationFactoryProtocol {
    func createDurationOperation(
        from runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        blockTimeEstimationService: BlockTimeEstimationServiceProtocol
    ) -> CompoundOperationWrapper<ParachainStakingDuration>
}

final class ParaStkDurationOperationFactory: ParaStkDurationOperationFactoryProtocol {
    let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol

    init(
        storageRequestFactory: StorageRequestFactoryProtocol,
        blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    ) {
        self.storageRequestFactory = storageRequestFactory
        self.blockTimeOperationFactory = blockTimeOperationFactory
    }

    private func createRoundDurationWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<UInt32> {
        let wrapper: CompoundOperationWrapper<StorageResponse<ParachainStaking.RoundInfo>> = storageRequestFactory.queryItem(
            engine: connection,
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: ParachainStaking.roundPath
        )

        let mappingOperation = ClosureOperation<UInt32> {
            guard let length = try wrapper.targetOperation.extractNoCancellableResultData().value?.length else {
                throw CommonError.dataCorruption
            }

            return length
        }

        mappingOperation.addDependency(wrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: wrapper.allOperations)
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

        let roundDurationWrapper: CompoundOperationWrapper<UInt32> = createRoundDurationWrapper(
            dependingOn: codingFactoryOperation,
            connection: connection
        )

        roundDurationWrapper.addDependency(operations: [codingFactoryOperation])

        let unstakingPeriodOperation: BaseOperation<Int32> = PrimitiveConstantOperation.operation(
            for: ParachainStaking.delegationBondLessDelay,
            dependingOn: codingFactoryOperation
        )

        unstakingPeriodOperation.addDependency(codingFactoryOperation)

        let mapOperation = ClosureOperation<ParachainStakingDuration> {
            let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()
            let blocksInRound = try roundDurationWrapper.targetOperation.extractNoCancellableResultData()
            let unstakingRounds = try unstakingPeriodOperation.extractNoCancellableResultData()

            let blockTimeInterval = TimeInterval(blockTime).seconds
            let roundDuration = TimeInterval(blocksInRound) * blockTimeInterval
            let unstakingDuration = TimeInterval(unstakingRounds) * roundDuration

            return ParachainStakingDuration(
                block: blockTimeInterval,
                round: roundDuration,
                unstaking: unstakingDuration
            )
        }

        let dependencies = [codingFactoryOperation, unstakingPeriodOperation] +
            roundDurationWrapper.allOperations + blockTimeWrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }
}
