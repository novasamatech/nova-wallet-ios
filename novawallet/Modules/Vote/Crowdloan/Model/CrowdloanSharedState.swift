import Foundation
import Keystore_iOS

struct CrowdloanSharedState {
    let settings: CrowdloanChainSettings
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    
    private var blockTimeService: BlockTimeEstimationServiceProtocol?
    
    init(
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        internalSettings: SettingsManagerProtocol = SettingsManager.shared,
        storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared,
        operationQueue: OperationQueue = OperationQueue(),
        logger: LoggerProtocol = Logger.shared
    ) {
        settings = CrowdloanChainSettings(
            chainRegistry: chainRegistry,
            settings: internalSettings
        )
        
        generalLocalSubscriptionFactory = GeneralStorageSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManager(operationQueue: operationQueue),
            logger: logger
        )
    }
}

extension CrowdloanSharedState {
    func replaceBlockTimeService(_ newService: BlockTimeEstimationServiceProtocol?) {
        blockTimeService = newService
    }
}
