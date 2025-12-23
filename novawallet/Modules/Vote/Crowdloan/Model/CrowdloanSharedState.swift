import Foundation
import Operation_iOS
import Keystore_iOS

final class CrowdloanSharedState {
    let settings: CrowdloanChainSettings
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let crowdloanSubscriptionFactory: CrowdloanLocalSubscriptionMaking
    let chainRegistry: ChainRegistryProtocol

    private var blockTimeService: BlockTimeEstimationServiceProtocol?

    init(
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        internalSettings: SettingsManagerProtocol = SettingsManager.shared,
        storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared,
        operationQueue: OperationQueue = OperationQueue(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.chainRegistry = chainRegistry

        settings = CrowdloanChainSettings(
            chainRegistry: chainRegistry,
            settings: internalSettings
        )

        let operationManager = OperationManager(operationQueue: operationQueue)

        generalLocalSubscriptionFactory = GeneralStorageSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )

        crowdloanSubscriptionFactory = CrowdloanLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )
    }
}

extension CrowdloanSharedState {
    func replaceBlockTimeService(_ newService: BlockTimeEstimationServiceProtocol?) {
        blockTimeService?.throttle()
        blockTimeService = newService
    }

    func createChainTimelineFacade() -> ChainTimelineFacadeProtocol? {
        guard let chain = settings.value, let blockTimeService else {
            return nil
        }

        return ChainTimelineFacade(
            chainId: chain.chainId,
            chainRegistry: chainRegistry,
            estimationService: blockTimeService
        )
    }
}
