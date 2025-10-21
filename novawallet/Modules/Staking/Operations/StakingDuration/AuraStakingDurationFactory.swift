import Foundation
import Operation_iOS

final class AuraStakingDurationFactory: StakingDurationOperationFactoryProtocol {
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    let sessionPeriodOperationFactory: StakingSessionPeriodOperationFactoryProtocol
    let eraLengthOperationFactory: EraLengthOperationFactoryProtocol

    init(
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeOperationFactory: BlockTimeOperationFactoryProtocol,
        sessionPeriodOperationFactory: StakingSessionPeriodOperationFactoryProtocol
    ) {
        self.chainId = chainId
        self.chainRegistry = chainRegistry
        self.blockTimeService = blockTimeService
        self.blockTimeOperationFactory = blockTimeOperationFactory
        self.sessionPeriodOperationFactory = sessionPeriodOperationFactory
        eraLengthOperationFactory = EraLengthOperationFactory(chainRegistry: chainRegistry)
    }

    func createDurationOperation() -> CompoundOperationWrapper<StakingDuration> {
        do {
            let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: chainId)

            let runtimeFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let unlockingOperation: BaseOperation<UInt32> = PrimitiveConstantOperation.operation(
                for: Staking.lockUpPeriodPath,
                dependingOn: runtimeFactoryOperation
            )

            let eraLengthWrapper = eraLengthOperationFactory.createEraLengthWrapper(for: chainId)

            let sessionLengthOperation = sessionPeriodOperationFactory.createOperation(dependingOn: runtimeFactoryOperation)

            let blockTimeWrapper = blockTimeOperationFactory.createBlockTimeOperation(
                from: runtimeService,
                blockTimeEstimationService: blockTimeService
            )

            let mergeOperation = ClosureOperation<StakingDuration> {
                let sessionLength = try sessionLengthOperation.extractNoCancellableResultData()
                let eraLength = try eraLengthWrapper.targetOperation.extractNoCancellableResultData()
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

            let constOperations = [unlockingOperation, sessionLengthOperation] + eraLengthWrapper.allOperations

            constOperations.forEach { constOperation in
                constOperation.addDependency(runtimeFactoryOperation)
                mergeOperation.addDependency(constOperation)
                mergeOperation.addDependency(blockTimeWrapper.targetOperation)
            }

            return CompoundOperationWrapper(
                targetOperation: mergeOperation,
                dependencies: [runtimeFactoryOperation] + constOperations + blockTimeWrapper.allOperations
            )
        } catch {
            return .createWithError(error)
        }
    }
}
