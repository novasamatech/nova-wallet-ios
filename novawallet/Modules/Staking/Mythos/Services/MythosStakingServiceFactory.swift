import Foundation

protocol MythosStakingServiceFactoryProtocol {
    func createSelectedCollatorsService(
        for chainId: ChainModel.Id
    ) throws -> MythosCollatorServiceProtocol

    func createRewardCalculatorService(
        for chainAssetId: ChainAssetId,
        collatorService: MythosCollatorServiceProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol
    ) throws -> CollatorStakingRewardCalculatorServiceProtocol

    func createBlockTimeService(for chainId: ChainModel.Id) throws -> BlockTimeEstimationServiceProtocol
}

final class MythosStakingServiceFactory: CollatorStakingServiceFactory {}

extension MythosStakingServiceFactory: MythosStakingServiceFactoryProtocol {
    func createSelectedCollatorsService(
        for chainId: ChainModel.Id
    ) throws -> MythosCollatorServiceProtocol {
        MythosCollatorService(
            chainId: chainId,
            chainRegistry: chainRegisty,
            operationQueue: operationQueue,
            eventCenter: eventCenter,
            logger: logger
        )
    }

    func createRewardCalculatorService(
        for chainAssetId: ChainAssetId,
        collatorService: MythosCollatorServiceProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol
    ) throws -> CollatorStakingRewardCalculatorServiceProtocol {
        let chain = try chainRegisty.getChainOrError(for: chainAssetId.chainId)
        let chainAsset = try chain.chainAssetOrError(for: chainAssetId.assetId)

        let runtimeService = try chainRegisty.getRuntimeProviderOrError(for: chain.chainId)

        let blockTimeOperationFactory = BlockTimeOperationFactory(chain: chain)

        return MythosRewardCalculatorService(
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            blockTimeOperationFactory: blockTimeOperationFactory,
            blockTimeService: blockTimeService,
            runtimeService: runtimeService,
            collatorService: collatorService,
            operationQueue: operationQueue,
            eventCenter: eventCenter,
            logger: logger
        )
    }
}
