import Foundation
import Operation_iOS
import SubstrateSdk

struct MythosStakingDuration: Equatable {
    let block: TimeInterval
    let session: TimeInterval
    let unstaking: TimeInterval
    let sessionInfo: ChainSessionInfo
}

protocol MythosStkDurationOperationFactoryProtocol {
    func createDurationOperation(
        for chainId: ChainModel.Id,
        blockTimeEstimationService: BlockTimeEstimationServiceProtocol
    ) -> CompoundOperationWrapper<MythosStakingDuration>
}

enum MythosStkDurationOperationFactoryError: Error {
    case sessionLengthMissing
}

final class MythosStkDurationOperationFactory {
    let chainRegistry: ChainRegistryProtocol
    let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.blockTimeOperationFactory = blockTimeOperationFactory
    }
}

extension MythosStkDurationOperationFactory: MythosStkDurationOperationFactoryProtocol {
    func createDurationOperation(
        for chainId: ChainModel.Id,
        blockTimeEstimationService: BlockTimeEstimationServiceProtocol
    ) -> CompoundOperationWrapper<MythosStakingDuration> {
        do {
            let chain = try chainRegistry.getChainOrError(for: chainId)

            guard let blocksInSession = chain.additional?.sessionLength?.unsignedIntValue else {
                throw MythosStkDurationOperationFactoryError.sessionLengthMissing
            }

            let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)

            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let unstakingPeriodOperation: BaseOperation<BlockNumber> = PrimitiveConstantOperation.operation(
                for: MythosStakingPallet.stakeUnlockDelayPath,
                dependingOn: codingFactoryOperation
            )

            unstakingPeriodOperation.addDependency(codingFactoryOperation)

            let blockTimeWrapper = blockTimeOperationFactory.createBlockTimeOperation(
                from: runtimeService,
                blockTimeEstimationService: blockTimeEstimationService
            )

            let mapOperation = ClosureOperation<MythosStakingDuration> {
                let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()
                let unstakingBlocks = try unstakingPeriodOperation.extractNoCancellableResultData()

                let blockTimeInterval = TimeInterval(blockTime).seconds
                let sessionDuration = TimeInterval(blocksInSession) * blockTimeInterval
                let unstakingDuration = TimeInterval(unstakingBlocks) * blockTimeInterval

                return MythosStakingDuration(
                    block: blockTimeInterval,
                    session: sessionDuration,
                    unstaking: unstakingDuration,
                    sessionInfo: ChainSessionInfo(
                        offset: 0,
                        length: SessionIndex(blocksInSession)
                    )
                )
            }

            mapOperation.addDependency(blockTimeWrapper.targetOperation)
            mapOperation.addDependency(unstakingPeriodOperation)

            return blockTimeWrapper
                .insertingHead(operations: [codingFactoryOperation, unstakingPeriodOperation])
                .insertingTail(operation: mapOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
