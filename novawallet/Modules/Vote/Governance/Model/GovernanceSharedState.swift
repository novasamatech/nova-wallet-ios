import Foundation
import SoraKeystore
import RobinHood
import SubstrateSdk

final class GovernanceSharedState {
    let settings: GovernanceChainSettings
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol
    let jsonDataProviderFactory: JsonDataProviderFactoryProtocol
    let applicationConfig: ApplicationConfigProtocol
    let requestFactory: StorageRequestFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    private(set) var subscriptionFactory: GovernanceSubscriptionFactoryProtocol?
    private(set) var referendumsOperationFactory: ReferendumsOperationFactoryProtocol?
    private(set) var locksOperationFactory: GovernanceLockStateFactoryProtocol?
    private(set) var blockTimeService: BlockTimeEstimationServiceProtocol?

    private(set) var delegationsMetadataProvider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]>?
    private(set) var offchainVotingFactory: GovernanceOffchainVotingFactoryProtocol?

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
        jsonDataProviderFactory: JsonDataProviderFactoryProtocol = JsonDataProviderFactory.shared,
        applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared,
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

        self.jsonDataProviderFactory = jsonDataProviderFactory
        self.applicationConfig = applicationConfig

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

    func replaceGovernanceOffchainServices(for option: GovernanceSelectedOption?) {
        delegationsMetadataProvider = nil
        offchainVotingFactory = nil

        guard let option = option else {
            return
        }

        let chainId = option.chain.chainId

        switch option.type {
        case .governanceV2:
            if let offchainApi = option.chain.externalApis?.governanceDelegations()?.first {
                offchainVotingFactory = SubqueryVotingOperationFactory(url: offchainApi.url)
            }

            let url = GovernanceDelegateMetadataFactory().createUrl(for: option.chain)
            delegationsMetadataProvider = jsonDataProviderFactory.getJson(for: url)

        case .governanceV1:
            break
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

    func createBlockTimeOperationFactory() -> BlockTimeOperationFactoryProtocol? {
        guard let chain = settings.value?.chain else {
            return nil
        }

        return BlockTimeOperationFactory(chain: chain)
    }
}
