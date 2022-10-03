import Foundation
import SoraKeystore

final class GovernanceSharedState {
    let settings: GovernanceChainSettings

    init(
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        internalSettings: SettingsManagerProtocol = SettingsManager.shared
    ) {
        settings = GovernanceChainSettings(chainRegistry: chainRegistry, settings: internalSettings)
    }
}
