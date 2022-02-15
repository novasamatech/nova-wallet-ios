import Foundation
import SoraKeystore
import RobinHood

final class CrowdloanSharedState {
    let settings: CrowdloanChainSettings
    let crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol
    let crowdloanOffchainProviderFactory: CrowdloanOffchainProviderFactoryProtocol

    init(
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared,
        internalSettings: SettingsManagerProtocol = SettingsManager.shared,
        operationManager: OperationManagerProtocol = OperationManagerFacade.sharedManager,
        logger: LoggerProtocol = Logger.shared
    ) {
        settings = CrowdloanChainSettings(
            chainRegistry: chainRegistry,
            settings: internalSettings
        )

        crowdloanLocalSubscriptionFactory = CrowdloanLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )

        crowdloanOffchainProviderFactory = CrowdloanOffchainProviderFactory(storageFacade: storageFacade)
    }

    init(
        settings: CrowdloanChainSettings,
        crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol,
        crowdloanOffchainProviderFactory: CrowdloanOffchainProviderFactoryProtocol
    ) {
        self.settings = settings
        self.crowdloanLocalSubscriptionFactory = crowdloanLocalSubscriptionFactory
        self.crowdloanOffchainProviderFactory = crowdloanOffchainProviderFactory
    }
}
