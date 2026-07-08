import Foundation
import Operation_iOS

final class BabeStakingDurationFactory {
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    let eraLengthOperationFactory: EraLengthOperationFactoryProtocol
    let unstakingDurationFactory: UnstakingDurationOperationMaking

    convenience init(
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.init(
            chainId: chainId,
            chainRegistry: chainRegistry,
            unstakingDurationFactory: UnstakingDurationOperationFactory(
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            )
        )
    }

    init(
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        unstakingDurationFactory: UnstakingDurationOperationMaking
    ) {
        self.chainId = chainId
        self.chainRegistry = chainRegistry
        eraLengthOperationFactory = EraLengthOperationFactory(chainRegistry: chainRegistry)
        self.unstakingDurationFactory = unstakingDurationFactory
    }
}

extension BabeStakingDurationFactory: StakingDurationOperationFactoryProtocol {
    func createDurationOperation() -> CompoundOperationWrapper<StakingDuration> {
        do {
            let timelineChain = try chainRegistry.getTimelineChainOrError(for: chainId)
            let timelineRuntimeService = try chainRegistry.getRuntimeProviderOrError(for: timelineChain.chainId)

            let unstakingWrapper = unstakingDurationFactory.createUnstakingDurationWrapper(for: chainId)

            let eraLengthWrapper = try eraLengthOperationFactory.createEraLengthWrapper(for: chainId)

            let sessionLengthWrapper: CompoundOperationWrapper<SessionIndex> = PrimitiveConstantOperation.wrapper(
                for: BabePallet.sessionLengthPath,
                runtimeService: timelineRuntimeService
            )

            let blockTimeWrapper: CompoundOperationWrapper<Moment> = PrimitiveConstantOperation.wrapper(
                for: BabePallet.blockTimePath,
                runtimeService: timelineRuntimeService
            )

            let mergeOperation = ClosureOperation<StakingDuration> {
                let sessionLength = try sessionLengthWrapper.targetOperation.extractNoCancellableResultData()
                let eraLength = try eraLengthWrapper.targetOperation.extractNoCancellableResultData()
                let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()
                let unstaking = try unstakingWrapper.targetOperation.extractNoCancellableResultData()

                let sessionDuration = TimeInterval(sessionLength * blockTime).seconds
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

            mergeOperation.addDependency(sessionLengthWrapper.targetOperation)
            mergeOperation.addDependency(eraLengthWrapper.targetOperation)
            mergeOperation.addDependency(blockTimeWrapper.targetOperation)
            mergeOperation.addDependency(unstakingWrapper.targetOperation)

            return blockTimeWrapper
                .insertingHead(operations: sessionLengthWrapper.allOperations)
                .insertingHead(operations: eraLengthWrapper.allOperations)
                .insertingHead(operations: unstakingWrapper.allOperations)
                .insertingTail(operation: mergeOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
