import Foundation
import RobinHood
import SubstrateSdk

protocol RelaychainConsensusStateDepending {
    func createNetworkInfoOperationFactory(
        for chain: ChainModel,
        durationFactory: StakingDurationOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) -> NetworkStakingInfoOperationFactoryProtocol

    func createEraCountdownOperationFactory(
        for chain: ChainModel,
        timeModel: StakingTimeModel,
        operationQueue: OperationQueue
    ) -> EraCountdownOperationFactoryProtocol

    func createStakingDurationOperationFactory(
        for chain: ChainModel,
        timeModel: StakingTimeModel
    ) -> StakingDurationOperationFactoryProtocol
}

final class RelaychainConsensusStateDependingFactory: RelaychainConsensusStateDepending {
    func createNetworkInfoOperationFactory(
        for chain: ChainModel,
        durationFactory: StakingDurationOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) -> NetworkStakingInfoOperationFactoryProtocol {
        let votersInfoOperationFactory = VotersInfoOperationFactory(
            chain: chain,
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        return NetworkStakingInfoOperationFactory(
            durationFactory: durationFactory,
            votersOperationFactory: votersInfoOperationFactory
        )
    }

    func createEraCountdownOperationFactory(
        for chain: ChainModel,
        timeModel: StakingTimeModel,
        operationQueue: OperationQueue
    ) -> EraCountdownOperationFactoryProtocol {
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        switch timeModel {
        case .babe:
            return BabeEraOperationFactory(storageRequestFactory: storageRequestFactory)
        case let .auraGeneral(blockTimeService):
            return AuraEraOperationFactory(
                storageRequestFactory: storageRequestFactory,
                blockTimeService: blockTimeService,
                blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain),
                sessionPeriodOperationFactory: PathStakingSessionPeriodOperationFactory(path: .electionsSessionPeriod)
            )
        case let .azero(blockTimeService):
            return AuraEraOperationFactory(
                storageRequestFactory: storageRequestFactory,
                blockTimeService: blockTimeService,
                blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain),
                sessionPeriodOperationFactory: PathStakingSessionPeriodOperationFactory(path: .azeroSessionPeriod)
            )
        }
    }

    func createStakingDurationOperationFactory(
        for chain: ChainModel,
        timeModel: StakingTimeModel
    ) -> StakingDurationOperationFactoryProtocol {
        switch timeModel {
        case .babe:
            return BabeStakingDurationFactory()
        case let .auraGeneral(blockTimeService):
            return AuraStakingDurationFactory(
                blockTimeService: blockTimeService,
                blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain),
                sessionPeriodOperationFactory: PathStakingSessionPeriodOperationFactory(path: .electionsSessionPeriod)
            )
        case let .azero(blockTimeService):
            return AuraStakingDurationFactory(
                blockTimeService: blockTimeService,
                blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain),
                sessionPeriodOperationFactory: PathStakingSessionPeriodOperationFactory(path: .azeroSessionPeriod)
            )
        }
    }
}
