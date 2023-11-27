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
        operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.chainRegistry = chainRegistry
        settings = GovernanceChainSettings(chainRegistry: chainRegistry, settings: internalSettings)

        govMetadataLocalSubscriptionFactory = GovMetadataLocalSubscriptionFactory(
            storageFacade: substrateStorageFacade,
            operationQueue: operationQueue,
            logger: logger
        )

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

    func replaceGovernanceFactory(for option: GovernanceSelectedOption?) {
        subscriptionFactory = nil
        referendumsOperationFactory = nil
        locksOperationFactory = nil

        guard let option = option else {
            return
        }

        let chainId = option.chain.chainId

        switch option.type {
        case .governanceV2:
            let operationFactory = Gov2OperationFactory(
                requestFactory: requestFactory,
                commonOperationFactory: GovCommonOperationFactory(),
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
        case .governanceV1:
            let operationFactory = Gov1OperationFactory(
                requestFactory: requestFactory,
                commonOperationFactory: GovCommonOperationFactory(),
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

    func createExtrinsicFactory(
        for option: GovernanceSelectedOption
    ) -> GovernanceExtrinsicFactoryProtocol {
        switch option.type {
        case .governanceV2:
            return Gov2ExtrinsicFactory()
        case .governanceV1:
            return Gov1ExtrinsicFactory()
        }
    }

    func createActionsDetailsFactory(
        for option: GovernanceSelectedOption
    ) -> ReferendumActionOperationFactoryProtocol {
        switch option.type {
        case .governanceV2:
            return Gov2ActionOperationFactory(
                requestFactory: requestFactory,
                operationQueue: operationQueue
            )
        case .governanceV1:
            let gov2ActionsFactory = Gov2ActionOperationFactory(
                requestFactory: requestFactory,
                operationQueue: operationQueue
            )

            return Gov1ActionOperationFactory(
                gov2OperationFactory: gov2ActionsFactory,
                requestFactory: requestFactory,
                operationQueue: operationQueue
            )
        }
    }

    func governanceId(for option: GovernanceSelectedOption) -> String {
        switch option.type {
        case .governanceV2:
            return ConvictionVoting.lockId
        case .governanceV1:
            return Democracy.lockId
        }
    }

    func supportsDelegations(for option: GovernanceSelectedOption) -> Bool {
        switch option.type {
        case .governanceV2:
            if let delegationsApi = option.chain.externalApis?.governanceDelegations() {
                return !delegationsApi.isEmpty
            } else {
                return false
            }
        case .governanceV1:
            return false
        }
    }

    func createBlockTimeOperationFactory() -> BlockTimeOperationFactoryProtocol? {
        guard let chain = settings.value?.chain else {
            return nil
        }

        return BlockTimeOperationFactory(chain: chain)
    }

    func createOffchainAllVotesFactory(
        for option: GovernanceSelectedOption
    ) -> GovernanceOffchainVotingWrapperFactoryProtocol? {
        switch option.type {
        case .governanceV1:
            return nil
        case .governanceV2:
            guard let delegationApi = option.chain.externalApis?.governanceDelegations()?.first else {
                return nil
            }

            let identityOperationFactory = IdentityOperationFactory(
                requestFactory: requestFactory,
                emptyIdentitiesWhenNoStorage: true
            )

            let fetchOperationFactory = SubqueryVotingOperationFactory(url: delegationApi.url)

            return GovernanceOffchainVotingWrapperFactory(
                operationFactory: fetchOperationFactory,
                identityOperationFactory: identityOperationFactory
            )
        }
    }

    func createOffchainDelegateListFactory(
        for option: GovernanceSelectedOption
    ) -> GovernanceDelegateListFactoryProtocol? {
        switch option.type {
        case .governanceV1:
            return nil
        case .governanceV2:
            guard let delegationApi = option.chain.externalApis?.governanceDelegations()?.first else {
                return nil
            }

            let statsOperationFactory = SubqueryDelegateStatsOperationFactory(url: delegationApi.url)
            let delegateMetadataFactory = GovernanceDelegateMetadataFactory()

            let identityOperationFactory = IdentityOperationFactory(
                requestFactory: requestFactory,
                emptyIdentitiesWhenNoStorage: true
            )

            return GovernanceDelegateListOperationFactory(
                statsOperationFactory: statsOperationFactory,
                metadataOperationFactory: delegateMetadataFactory,
                identityOperationFactory: identityOperationFactory
            )
        }
    }
}
