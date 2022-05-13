import Foundation
import RobinHood

struct ParachainStakingDuration {
    let round: TimeInterval
    let unstaking: TimeInterval
}

protocol ParaStkDurationOperationFactoryProtocol {
    func createDurationOperation(
        from runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<ParachainStakingDuration>
}

final class ParaStkDurationOperationFactory: ParaStkDurationOperationFactoryProtocol {
    func createDurationOperation(
        from runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<ParachainStakingDuration> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let blockTimeOperation = ClosureOperation<TimeInterval> {
            // TODO: fetch dynamic block time
            15.0
        }

        let roundDurationOperation: BaseOperation<Int32> = PrimitiveConstantOperation.operation(
            for: ParachainStaking.blocksPerRound,
            dependingOn: codingFactoryOperation
        )

        let unstakingPeriodOperation: BaseOperation<Int32> = PrimitiveConstantOperation.operation(
            for: ParachainStaking.delegationBondLessDelay,
            dependingOn: codingFactoryOperation
        )

        [blockTimeOperation, roundDurationOperation, unstakingPeriodOperation].forEach {
            $0.addDependency(codingFactoryOperation)
        }

        let mapOperation = ClosureOperation<ParachainStakingDuration> {
            let blockTime = try blockTimeOperation.extractNoCancellableResultData()
            let blocksInRound = try roundDurationOperation.extractNoCancellableResultData()
            let unstakingRounds = try unstakingPeriodOperation.extractNoCancellableResultData()

            let roundDuration = TimeInterval(blocksInRound) * blockTime
            let unstakingDuration = TimeInterval(unstakingRounds) * roundDuration

            return ParachainStakingDuration(round: roundDuration, unstaking: unstakingDuration)
        }

        let dependencies = [
            codingFactoryOperation,
            blockTimeOperation,
            roundDurationOperation,
            unstakingPeriodOperation
        ]

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }
}
