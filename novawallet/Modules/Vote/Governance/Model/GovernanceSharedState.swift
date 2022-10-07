import Foundation
import SoraKeystore

final class GovernanceSharedState {
    let settings: GovernanceChainSettings
    let govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol

    init(
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        substrateStorageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared,
        internalSettings: SettingsManagerProtocol = SettingsManager.shared
    ) {
        settings = GovernanceChainSettings(chainRegistry: chainRegistry, settings: internalSettings)
        govMetadataLocalSubscriptionFactory = GovMetadataLocalSubscriptionFactory(storageFacade: substrateStorageFacade)
    }
}
