import Foundation
import SoraKeystore
import RobinHood
import SubstrateSdk

final class GovernanceSharedState {
    let settings: GovernanceChainSettings
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol
    let requestFactory: StorageRequestFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    private(set) var subscriptionFactory: GovernanceSubscriptionFactoryProtocol?
    private(set) var referendumsOperationFactory: ReferendumsOperationFactoryProtocol?
    private(set) var locksOperationFactory: GovernanceLockStateFactoryProtocol?
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

    func replaceGovernanceFactory(for chain: ChainModel?) {
        subscriptionFactory = nil
        referendumsOperationFactory = nil
        locksOperationFactory = nil

        guard let chain = chain else {
            return
        }

        let chainId = chain.chainId

        if chain.hasGov2 {
            let operationFactory = Gov2OperationFactory(
                requestFactory: requestFactory,
                operationQueue: operationQueue
            )

            referendumsOperationFactory = operationFactory

            subscriptionFactory = Gov2SubscriptionFactory(
                chainId: chainId,
                operationFactory: operationFactory,
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            )

            locksOperationFactory = Gov2LockStateFactory(
                requestFactory: requestFactory,
                unlocksCalculator: GovUnlocksCalculator()
            )
        } else if chain.hasGov1 {
            let operationFactory = Gov1OperationFactory(
                requestFactory: requestFactory,
                operationQueue: operationQueue
            )

            referendumsOperationFactory = operationFactory

            subscriptionFactory = Gov1SubscriptionFactory(
                chainId: chainId,
                operationFactory: operationFactory,
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            )

            locksOperationFactory = Gov1LockStateFactory(
                requestFactory: requestFactory,
                unlocksCalculator: GovUnlocksCalculator()
            )
        }
    }

    func createExtrinsicFactory(for chain: ChainModel) -> GovernanceExtrinsicFactoryProtocol? {
        if chain.hasGov2 {
            return Gov2ExtrinsicFactory()
        } else if chain.hasGov1 {
            return Gov1ExtrinsicFactory()
        } else {
            return nil
        }
    }

    func createActionsDetailsFactory(for chain: ChainModel) -> ReferendumActionOperationFactoryProtocol? {
        if chain.hasGov2 {
            return Gov2ActionOperationFactory(
                requestFactory: requestFactory,
                operationQueue: operationQueue
            )
        } else if chain.hasGov1 {
            let gov2ActionsFactory = Gov2ActionOperationFactory(
                requestFactory: requestFactory,
                operationQueue: operationQueue
            )

            return Gov1ActionOperationFactory(
                gov2OperationFactory: gov2ActionsFactory,
                requestFactory: requestFactory,
                operationQueue: operationQueue
            )
        } else {
            return nil
        }
    }

    func governanceId(for chain: ChainModel) -> String? {
        if chain.hasGov2 {
            return ConvictionVoting.lockId
        } else if chain.hasGov1 {
            return Democracy.lockId
        } else {
            return nil
        }
    }
}
