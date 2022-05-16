import Foundation
import RobinHood

struct ParachainStakingDuration {
    let block: TimeInterval
    let round: TimeInterval
    let unstaking: TimeInterval
}

protocol ParaStkDurationOperationFactoryProtocol {
    func createDurationOperation(
        from runtimeService: RuntimeCodingServiceProtocol,
        blockTimeEstimationService: BlockTimeEstimationServiceProtocol
    ) -> CompoundOperationWrapper<ParachainStakingDuration>
}

final class ParaStkDurationOperationFactory: ParaStkDurationOperationFactoryProtocol {
    let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol

    init(blockTimeOperationFactory: BlockTimeOperationFactoryProtocol) {
        self.blockTimeOperationFactory = blockTimeOperationFactory
    }

    func createDurationOperation(
        from runtimeService: RuntimeCodingServiceProtocol,
        blockTimeEstimationService: BlockTimeEstimationServiceProtocol
    ) -> CompoundOperationWrapper<ParachainStakingDuration> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let blockTimeWrapper = blockTimeOperationFactory.createBlockTimeOperation(
            from: runtimeService,
            blockTimeEstimationService: blockTimeEstimationService
        )

        let roundDurationOperation: BaseOperation<Int32> = PrimitiveConstantOperation.operation(
            for: ParachainStaking.blocksPerRound,
            dependingOn: codingFactoryOperation
        )

        let unstakingPeriodOperation: BaseOperation<Int32> = PrimitiveConstantOperation.operation(
            for: ParachainStaking.delegationBondLessDelay,
            dependingOn: codingFactoryOperation
        )

        [roundDurationOperation, unstakingPeriodOperation].forEach {
            $0.addDependency(codingFactoryOperation)
        }

        let mapOperation = ClosureOperation<ParachainStakingDuration> {
            let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()
            let blocksInRound = try roundDurationOperation.extractNoCancellableResultData()
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

        let dependencies = [
            codingFactoryOperation,
            roundDurationOperation,
            unstakingPeriodOperation
        ] + blockTimeWrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }
}
