import Foundation
import SoraKeystore
import RobinHood
import SubstrateSdk

final class GovernanceSharedState {
    let settings: GovernanceChainSettings
    let govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let requestFactory: StorageRequestFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    private(set) var subscriptionFactory: GovernanceSubscriptionFactoryProtocol?
    private(set) var blockTimeService: BlockTimeEstimationServiceProtocol?

    init(
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        substrateStorageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol? = nil,
        blockTimeService: BlockTimeEstimationServiceProtocol? = nil,
        internalSettings: SettingsManagerProtocol = SettingsManager.shared,
        requestFactory: StorageRequestFactoryProtocol = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: OperationManagerFacade.sharedDefaultQueue)
        ),
        operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue
    ) {
        self.chainRegistry = chainRegistry
        settings = GovernanceChainSettings(chainRegistry: chainRegistry, settings: internalSettings)
        govMetadataLocalSubscriptionFactory = GovMetadataLocalSubscriptionFactory(storageFacade: substrateStorageFacade)
        self.blockTimeService = blockTimeService

        if let generalLocalSubscriptionFactory = generalLocalSubscriptionFactory {
            self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        } else {
            self.generalLocalSubscriptionFactory = GeneralStorageSubscriptionFactory(
                chainRegistry: chainRegistry,
                storageFacade: substrateStorageFacade,
                operationManager: OperationManager(operationQueue: OperationManagerFacade.sharedDefaultQueue),
                logger: Logger.shared
            )
        }

        self.requestFactory = requestFactory
        self.operationQueue = operationQueue
    }

    func replaceBlockTimeService(_ newService: BlockTimeEstimationServiceProtocol?) {
        blockTimeService = newService
    }

    func replaceSubscriptionFactory(for chain: ChainModel?) {
        guard let chainId = chain?.chainId else {
            subscriptionFactory = nil
            return
        }

        let operationFactory = Gov2OperationFactory(
            requestFactory: requestFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        subscriptionFactory = Gov2SubscriptionFactory(
            chainId: chainId,
            operationFactory: operationFactory,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
    }
}
