import Foundation
import Operation_iOS

final class AuraStakingDurationFactory: StakingDurationOperationFactoryProtocol {
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    let sessionPeriodOperationFactory: StakingSessionPeriodOperationFactoryProtocol
    let eraLengthOperationFactory: EraLengthOperationFactoryProtocol
    let unstakingDurationFactory: UnstakingDurationOperationMaking

    init(
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeOperationFactory: BlockTimeOperationFactoryProtocol,
        sessionPeriodOperationFactory: StakingSessionPeriodOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainId = chainId
        self.chainRegistry = chainRegistry
        self.blockTimeService = blockTimeService
        self.blockTimeOperationFactory = blockTimeOperationFactory
        self.sessionPeriodOperationFactory = sessionPeriodOperationFactory
        eraLengthOperationFactory = EraLengthOperationFactory(chainRegistry: chainRegistry)
        unstakingDurationFactory = UnstakingDurationOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
    }

    func createDurationOperation() -> CompoundOperationWrapper<StakingDuration> {
        do {
            let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: chainId)

            let runtimeFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let unstakingWrapper = unstakingDurationFactory.createUnstakingDurationWrapper(for: chainId)

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
                let unstaking = try unstakingWrapper.targetOperation.extractNoCancellableResultData()

                let sessionDuration = TimeInterval(sessionLength * Moment(blockTime)).seconds
                let eraDuration = TimeInterval(eraLength) * sessionDuration
                let unlocking = UnlockingDuration(
                    validator: TimeInterval(unstaking.validator) * eraDuration,
                    nominator: TimeInterval(unstaking.nominator) * eraDuration
                )

                return StakingDuration(
                    session: sessionDuration,
                    era: eraDuration,
                    unlocking: unlocking
                )
            }

            let constOperations = [sessionLengthOperation] + eraLengthWrapper.allOperations

            constOperations.forEach { constOperation in
                constOperation.addDependency(runtimeFactoryOperation)
                mergeOperation.addDependency(constOperation)
                mergeOperation.addDependency(blockTimeWrapper.targetOperation)
            }

            mergeOperation.addDependency(unstakingWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: mergeOperation,
                dependencies: [runtimeFactoryOperation] + constOperations + blockTimeWrapper.allOperations + unstakingWrapper.allOperations
            )
        } catch {
            return .createWithError(error)
        }
    }
}
