import Foundation
import Operation_iOS

final class BabeStakingDurationFactory: StakingDurationOperationFactoryProtocol {
    func createDurationOperation(
        from runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<StakingDuration> {
        let runtimeFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let unlockingOperation: BaseOperation<UInt32> = createConstOperation(
            dependingOn: runtimeFactoryOperation,
            path: Staking.lockUpPeriodPath
        )

        let eraLengthOperation: BaseOperation<SessionIndex> = createConstOperation(
            dependingOn: runtimeFactoryOperation,
            path: Staking.eraLengthPath
        )

        let sessionLengthOperation: BaseOperation<SessionIndex> = createConstOperation(
            dependingOn: runtimeFactoryOperation,
            path: BabePallet.sessionLengthPath
        )

        let blockTimeOperation: BaseOperation<Moment> = createConstOperation(
            dependingOn: runtimeFactoryOperation,
            path: BabePallet.blockTimePath
        )

        let mergeOperation = ClosureOperation<StakingDuration> {
            let sessionLength = try sessionLengthOperation.extractNoCancellableResultData()
            let eraLength = try eraLengthOperation.extractNoCancellableResultData()
            let blockTime = try blockTimeOperation.extractNoCancellableResultData()
            let unlocking = try unlockingOperation.extractNoCancellableResultData()

            let sessionDuration = TimeInterval(sessionLength * blockTime).seconds
            let eraDuration = TimeInterval(eraLength) * sessionDuration
            let unlockingDuration = TimeInterval(unlocking) * eraDuration

            return StakingDuration(
                session: sessionDuration,
                era: eraDuration,
                unlocking: unlockingDuration
            )
        }

        let constOperations = [unlockingOperation, sessionLengthOperation,
                               eraLengthOperation, blockTimeOperation]

        constOperations.forEach { constOperation in
            constOperation.addDependency(runtimeFactoryOperation)
            mergeOperation.addDependency(constOperation)
        }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [runtimeFactoryOperation] + constOperations
        )
    }

    private func createConstOperation<T>(
        dependingOn runtimeFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        path: ConstantCodingPath
    ) -> PrimitiveConstantOperation<T> where T: LosslessStringConvertible {
        let operation = PrimitiveConstantOperation<T>(path: path)

        operation.configurationBlock = {
            do {
                operation.codingFactory = try runtimeFactoryOperation.extractNoCancellableResultData()
            } catch {
                operation.result = .failure(error)
            }
        }

        return operation
    }
}
