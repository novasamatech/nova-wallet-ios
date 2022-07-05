import Foundation

extension StakingSharedState {
    func createEraCountdownOperationFactory(
        for chain: ChainModel,
        storageRequestFactory: StorageRequestFactoryProtocol
    ) throws -> EraCountdownOperationFactoryProtocol {
        switch consensus {
        case .babe:
            return BabeEraOperationFactory(storageRequestFactory: storageRequestFactory)
        case .aura:
            guard let blockTimeService = blockTimeService else {
                throw StakingSharedStateError.missingBlockTimeService
            }

            return AuraEraOperationFactory(
                storageRequestFactory: storageRequestFactory,
                blockTimeService: blockTimeService,
                blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain)
            )
        }
    }

    func createStakingDurationOperationFactory(
        for chain: ChainModel
    ) throws -> StakingDurationOperationFactoryProtocol {
        switch consensus {
        case .babe:
            return BabeStakingDurationFactory()
        case .aura:
            guard let blockTimeService = blockTimeService else {
                throw StakingSharedStateError.missingBlockTimeService
            }

            return AuraStakingDurationFactory(
                blockTimeService: blockTimeService,
                blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain)
            )
        }
    }

    func createNetworkInfoOperationFactory(
        for chain: ChainModel
    ) throws -> NetworkStakingInfoOperationFactoryProtocol {
        let durationFactory = try createStakingDurationOperationFactory(for: chain)
        return NetworkStakingInfoOperationFactory(durationFactory: durationFactory)
    }
}
