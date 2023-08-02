import Foundation
import RobinHood
import SubstrateSdk

protocol RelaychainConsensusStateDepending {
    func createNetworkInfoOperationFactory(
        for durationFactory: StakingDurationOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) -> NetworkStakingInfoOperationFactoryProtocol

    func createEraCountdownOperationFactory(
        for consensus: ConsensusType,
        chain: ChainModel,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        operationQueue: OperationQueue
    ) -> EraCountdownOperationFactoryProtocol

    func createStakingDurationOperationFactory(
        for consensus: ConsensusType,
        chain: ChainModel,
        blockTimeService: BlockTimeEstimationServiceProtocol
    ) -> StakingDurationOperationFactoryProtocol
}

final class RelaychainConsensusStateDependingFactory: RelaychainConsensusStateDepending {
    func createNetworkInfoOperationFactory(
        for durationFactory: StakingDurationOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) -> NetworkStakingInfoOperationFactoryProtocol {
        let votersInfoOperationFactory = VotersInfoOperationFactory(
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        return NetworkStakingInfoOperationFactory(
            durationFactory: durationFactory,
            votersOperationFactory: votersInfoOperationFactory
        )
    }

    func createEraCountdownOperationFactory(
        for consensus: ConsensusType,
        chain: ChainModel,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        operationQueue: OperationQueue
    ) -> EraCountdownOperationFactoryProtocol {
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        switch consensus {
        case .babe:
            return BabeEraOperationFactory(storageRequestFactory: storageRequestFactory)
        case .auraGeneral:
            return AuraEraOperationFactory(
                storageRequestFactory: storageRequestFactory,
                blockTimeService: blockTimeService,
                blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain),
                sessionPeriodOperationFactory: PathStakingSessionPeriodOperationFactory(path: .electionsSessionPeriod)
            )
        case .auraAzero:
            return AuraEraOperationFactory(
                storageRequestFactory: storageRequestFactory,
                blockTimeService: blockTimeService,
                blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain),
                sessionPeriodOperationFactory: PathStakingSessionPeriodOperationFactory(path: .azeroSessionPeriod)
            )
        }
    }

    func createStakingDurationOperationFactory(
        for consensus: ConsensusType,
        chain: ChainModel,
        blockTimeService: BlockTimeEstimationServiceProtocol
    ) -> StakingDurationOperationFactoryProtocol {
        switch consensus {
        case .babe:
            return BabeStakingDurationFactory()
        case .auraGeneral:
            return AuraStakingDurationFactory(
                blockTimeService: blockTimeService,
                blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain),
                sessionPeriodOperationFactory: PathStakingSessionPeriodOperationFactory(path: .electionsSessionPeriod)
            )
        case .auraAzero:
            return AuraStakingDurationFactory(
                blockTimeService: blockTimeService,
                blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain),
                sessionPeriodOperationFactory: PathStakingSessionPeriodOperationFactory(path: .azeroSessionPeriod)
            )
        }
    }
}
