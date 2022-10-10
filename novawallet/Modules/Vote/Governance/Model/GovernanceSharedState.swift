import Foundation
import SoraKeystore

final class GovernanceSharedState {
    let settings: GovernanceChainSettings
    let govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol
    private(set) var blockTimeService: BlockTimeEstimationServiceProtocol?

    init(
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        substrateStorageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared,
        blockTimeService: BlockTimeEstimationServiceProtocol? = nil,
        internalSettings: SettingsManagerProtocol = SettingsManager.shared
    ) {
        settings = GovernanceChainSettings(chainRegistry: chainRegistry, settings: internalSettings)
        govMetadataLocalSubscriptionFactory = GovMetadataLocalSubscriptionFactory(storageFacade: substrateStorageFacade)
        self.blockTimeService = blockTimeService
    }

    func replaceBlockTimeService(_ newService: BlockTimeEstimationServiceProtocol?) {
        blockTimeService = newService
    }
}
