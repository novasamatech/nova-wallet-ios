import Foundation
import Operation_iOS

final class BabeStakingDurationFactory {
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol

    init(chainId: ChainModel.Id, chainRegistry: ChainRegistryProtocol) {
        self.chainId = chainId
        self.chainRegistry = chainRegistry
    }
}

extension BabeStakingDurationFactory: StakingDurationOperationFactoryProtocol {
    func createDurationOperation() -> CompoundOperationWrapper<StakingDuration> {
        do {
            let stakingRuntimeService = try chainRegistry.getRuntimeProviderOrError(for: chainId)
            let timelineChain = try chainRegistry.getTimelineChainOrError(for: chainId)
            let timelineRuntimeService = try chainRegistry.getRuntimeProviderOrError(for: timelineChain.chainId)

            let unlockingWrapper: CompoundOperationWrapper<UInt32> = PrimitiveConstantOperation.wrapper(
                for: Staking.lockUpPeriodPath,
                runtimeService: stakingRuntimeService
            )

            let eraLengthWrapper: CompoundOperationWrapper<SessionIndex> = PrimitiveConstantOperation.wrapper(
                for: Staking.eraLengthPath,
                runtimeService: stakingRuntimeService
            )

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
                let unlocking = try unlockingWrapper.targetOperation.extractNoCancellableResultData()

                let sessionDuration = TimeInterval(sessionLength * blockTime).seconds
                let eraDuration = TimeInterval(eraLength) * sessionDuration
                let unlockingDuration = TimeInterval(unlocking) * eraDuration

                return StakingDuration(
                    session: sessionDuration,
                    era: eraDuration,
                    unlocking: unlockingDuration
                )
            }

            mergeOperation.addDependency(sessionLengthWrapper.targetOperation)
            mergeOperation.addDependency(eraLengthWrapper.targetOperation)
            mergeOperation.addDependency(blockTimeWrapper.targetOperation)
            mergeOperation.addDependency(unlockingWrapper.targetOperation)

            return blockTimeWrapper
                .insertingHead(operations: sessionLengthWrapper.allOperations)
                .insertingHead(operations: eraLengthWrapper.allOperations)
                .insertingHead(operations: unlockingWrapper.allOperations)
                .insertingTail(operation: mergeOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
