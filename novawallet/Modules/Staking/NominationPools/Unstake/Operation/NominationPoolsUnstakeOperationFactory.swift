import Foundation
import Operation_iOS

protocol NPoolsUnstakeOperationFactoryProtocol {
    func createLimitsWrapper(
        for chain: ChainModel,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<NominationPools.UnstakeLimits>
}

final class NPoolsUnstakeOperationFactory {
    let unstakingDurationFactory: UnstakingDurationOperationMaking

    init(unstakingDurationFactory: UnstakingDurationOperationMaking) {
        self.unstakingDurationFactory = unstakingDurationFactory
    }

    private func createKnownPoolMemberChunksLimit(for chainId: ChainModel.Id) -> BaseOperation<UInt32?> {
        ClosureOperation<UInt32?> {
            switch chainId {
            case KnowChainId.alephZero:
                return 8
            default:
                return nil
            }
        }
    }
}

extension NPoolsUnstakeOperationFactory: NPoolsUnstakeOperationFactoryProtocol {
    func createLimitsWrapper(
        for chain: ChainModel,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<NominationPools.UnstakeLimits> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let maxUnlockingsOperation: PrimitiveConstantOperation<UInt32> = PrimitiveConstantOperation(
            path: Staking.maxUnlockingChunksConstantPath,
            fallbackValue: StakingConstants.maxUnlockingChunks
        )

        maxUnlockingsOperation.configurationBlock = {
            do {
                maxUnlockingsOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                maxUnlockingsOperation.result = .failure(error)
            }
        }

        maxUnlockingsOperation.addDependency(codingFactoryOperation)

        let knownPoolMemberChunksOperation = createKnownPoolMemberChunksLimit(for: chain.chainId)

        let unstakingDurationWrapper = unstakingDurationFactory.createUnstakingDurationWrapper(
            for: chain.chainId
        )

        let mapOperation = ClosureOperation<NominationPools.UnstakeLimits> {
            let maxUnlockChunks = try maxUnlockingsOperation.extractNoCancellableResultData()
            let maxMemberChunks = try knownPoolMemberChunksOperation.extractNoCancellableResultData()
            let unlockingDuration = try unstakingDurationWrapper.targetOperation
                .extractNoCancellableResultData().nominator

            return .init(
                globalMaxUnlockings: maxUnlockChunks,
                poolMemberMaxUnlockings: maxMemberChunks ?? maxUnlockChunks,
                bondingDuration: unlockingDuration
            )
        }

        let dependencies = [
            codingFactoryOperation,
            maxUnlockingsOperation,
            knownPoolMemberChunksOperation
        ] + unstakingDurationWrapper.allOperations

        dependencies.forEach { operation in
            mapOperation.addDependency(operation)
        }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }
}
