import Foundation

protocol MythosStakingServiceFactoryProtocol {
    func createSelectedCollatorsService(
        for chainId: ChainModel.Id
    ) throws -> MythosCollatorServiceProtocol

    func createRewardCalculatorService(
        for chainAssetId: ChainAssetId,
        stakingType: StakingType,
        collatorService: MythosCollatorServiceProtocol
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
        for _: ChainAssetId,
        stakingType _: StakingType,
        collatorService _: MythosCollatorServiceProtocol
    ) throws -> CollatorStakingRewardCalculatorServiceProtocol {
        MythosRewardCalculatorService()
    }
}
