import Foundation
import Operation_iOS
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
    let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }

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

        let timelineOperationFactory: RelayStkTimelineParamsOperationFactoryProtocol = switch timeModel {
        case .babe:
            BabeTimelineParamsOperationFactory(
                chainId: chain.chainId,
                chainRegistry: chainRegistry,
                storageRequestFactory: storageRequestFactory
            )
        case let .auraGeneral(blockTimeService):
            AuraTimelineParamsOperationFactory(
                chainId: chain.chainId,
                chainRegistry: chainRegistry,
                blockTimeService: blockTimeService,
                blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain),
                sessionPeriodOperationFactory: PathStakingSessionPeriodOperationFactory(path: .electionsSessionPeriod),
                storageRequestFactory: storageRequestFactory
            )
        case let .azero(blockTimeService):
            AuraTimelineParamsOperationFactory(
                chainId: chain.chainId,
                chainRegistry: chainRegistry,
                blockTimeService: blockTimeService,
                blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain),
                sessionPeriodOperationFactory: PathStakingSessionPeriodOperationFactory(path: .azeroSessionPeriod),
                storageRequestFactory: storageRequestFactory
            )
        }

        return RelayStkEraCountdownOperationFactory(
            chainId: chain.chainId,
            chainRegistry: chainRegistry,
            storageRequestFactory: storageRequestFactory,
            timelineOperationFactory: timelineOperationFactory,
            eraStartOperationFactory: RelayStkEraStartOperationFactory(
                chainRegistry: chainRegistry,
                storageRequestFactory: storageRequestFactory
            )
        )
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
