import Foundation
import Operation_iOS

final class AuraStakingDurationFactory: StakingDurationOperationFactoryProtocol {
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    let sessionPeriodOperationFactory: StakingSessionPeriodOperationFactoryProtocol

    init(
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeOperationFactory: BlockTimeOperationFactoryProtocol,
        sessionPeriodOperationFactory: StakingSessionPeriodOperationFactoryProtocol
    ) {
        self.blockTimeService = blockTimeService
        self.blockTimeOperationFactory = blockTimeOperationFactory
        self.sessionPeriodOperationFactory = sessionPeriodOperationFactory
    }

    func createDurationOperation(
        from runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<StakingDuration> {
        let runtimeFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let unlockingOperation: BaseOperation<UInt32> = PrimitiveConstantOperation.operation(
            for: Staking.lockUpPeriodPath,
            dependingOn: runtimeFactoryOperation
        )

        let eraLengthOperation: BaseOperation<SessionIndex> = PrimitiveConstantOperation.operation(
            for: Staking.eraLengthPath,
            dependingOn: runtimeFactoryOperation
        )

        let sessionLengthOperation = sessionPeriodOperationFactory.createOperation(dependingOn: runtimeFactoryOperation)

        let blockTimeWrapper = blockTimeOperationFactory.createBlockTimeOperation(
            from: runtimeService,
            blockTimeEstimationService: blockTimeService
        )

        let mergeOperation = ClosureOperation<StakingDuration> {
            let sessionLength = try sessionLengthOperation.extractNoCancellableResultData()
            let eraLength = try eraLengthOperation.extractNoCancellableResultData()
            let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()
            let unlocking = try unlockingOperation.extractNoCancellableResultData()

            let sessionDuration = TimeInterval(sessionLength * Moment(blockTime)).seconds
            let eraDuration = TimeInterval(eraLength) * sessionDuration
            let unlockingDuration = TimeInterval(unlocking) * eraDuration

            return StakingDuration(
                session: sessionDuration,
                era: eraDuration,
                unlocking: unlockingDuration
            )
        }

        let constOperations = [unlockingOperation, sessionLengthOperation, eraLengthOperation]

        constOperations.forEach { constOperation in
            constOperation.addDependency(runtimeFactoryOperation)
            mergeOperation.addDependency(constOperation)
            mergeOperation.addDependency(blockTimeWrapper.targetOperation)
        }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [runtimeFactoryOperation] + constOperations + blockTimeWrapper.allOperations
        )
    }
}
