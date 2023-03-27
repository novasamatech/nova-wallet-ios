import Foundation
import RobinHood

typealias ReferendumMetadataMapping = [ReferendumIdLocal: ReferendumMetadataLocal]

protocol GovMetadataLocalSubscriptionFactoryProtocol: AnyObject {
    func getMetadataProvider(
        for option: GovernanceSelectedOption
    ) -> StreamableProvider<ReferendumMetadataLocal>?

    func getMetadataProvider(
        for option: GovernanceSelectedOption,
        referendumId: ReferendumIdLocal
    ) -> StreamableProvider<ReferendumMetadataLocal>?
}

final class GovMetadataLocalSubscriptionFactory {
    private var providers: [String: WeakWrapper] = [:]

    let storageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(storageFacade: StorageFacadeProtocol, operationQueue: OperationQueue, logger: LoggerProtocol) {
        self.storageFacade = storageFacade
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func createPolkassemblyApiFactory(
        url: URL,
        chainId: ChainModel.Id,
        governanceType: GovernanceType
    ) -> GovMetadataOperationFactoryProtocol {
        switch governanceType {
        case .governanceV1:
            return GovernanceV1PolkassemblyOperationFactory(
                chainId: chainId,
                url: url
            )
        case .governanceV2:
            return GovernanceV2PolkassemblyOperationFactory(
                chainId: chainId,
                url: url
            )
        }
    }

    private func createSubsquareApiFactory(
        url: URL,
        chainId: ChainModel.Id,
        governanceType: GovernanceType
    ) -> GovMetadataOperationFactoryProtocol {
        switch governanceType {
        case .governanceV1:
            return GovV1SubsquareOperationFactory(
                baseUrl: url,
                chainId: chainId
            )
        case .governanceV2:
            return GovV2SubsquareOperationFactory(
                baseUrl: url,
                chainId: chainId
            )
        }
    }

    private func createOperationFactory(
        for apiType: GovernanceOffchainApi,
        url: URL,
        chainId: ChainModel.Id,
        governanceType: GovernanceType
    ) -> GovMetadataOperationFactoryProtocol? {
        switch apiType {
        case .polkassembly:
            return createPolkassemblyApiFactory(url: url, chainId: chainId, governanceType: governanceType)
        case .subsquare:
            return createSubsquareApiFactory(url: url, chainId: chainId, governanceType: governanceType)
        }
    }
}

extension GovMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol {
    func getMetadataProvider(
        for option: GovernanceSelectedOption
    ) -> StreamableProvider<ReferendumMetadataLocal>? {
        guard
            let governanceApi = option.chain.externalApis?.governance()?.first,
            let apiType = GovernanceOffchainApi(rawValue: governanceApi.serviceType) else {
            return nil
        }

        let chain = option.chain

        let chainId = chain.chainId
        let url = governanceApi.url

        let identifier = "gov-metadata-preview" + chainId

        if let provider = providers[identifier]?.target as? StreamableProvider<ReferendumMetadataLocal> {
            return provider
        }

        guard let operationFactory = createOperationFactory(
            for: apiType,
            url: url,
            chainId: chainId,
            governanceType: option.type
        ) else {
            return nil
        }

        let mapper = AnyCoreDataMapper(ReferendumMetadataMapper())
        let filter = NSPredicate.referendums(for: chainId)
        let repository = storageFacade.createRepository(filter: filter, sortDescriptors: [], mapper: mapper)

        let source = ReferendumsMetadataPreviewProviderSource(
            operationFactory: operationFactory,
            apiParameters: option.chain.externalApis?.governance()?.first?.parameters,
            repository: AnyDataProviderRepository(repository),
            operationQueue: operationQueue
        )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: mapper,
            predicate: { entity in
                chainId == entity.chainId
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Did receive error: \(error)")
            }
        }

        let provider = StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        providers[identifier] = WeakWrapper(target: provider)

        return provider
    }

    func getMetadataProvider(
        for option: GovernanceSelectedOption,
        referendumId: ReferendumIdLocal
    ) -> StreamableProvider<ReferendumMetadataLocal>? {
        guard
            let governanceApi = option.chain.externalApis?.governance()?.first,
            let apiType = GovernanceOffchainApi(rawValue: governanceApi.serviceType) else {
            return nil
        }

        let chainId = option.chain.chainId
        let url = governanceApi.url

        let identifier = "gov-metadata-details" + chainId + String(referendumId)

        if let provider = providers[identifier]?.target as? StreamableProvider<ReferendumMetadataLocal> {
            return provider
        }

        let mapper = ReferendumMetadataMapper()
        let repository = storageFacade.createRepository(
            filter: NSPredicate.referendums(for: chainId, referendumId: referendumId),
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        guard let operationFactory = createOperationFactory(
            for: apiType,
            url: url,
            chainId: chainId,
            governanceType: option.type
        ) else {
            return nil
        }

        let source = ReferendumMetadataDetailsProviderSource(
            chainId: chainId,
            referendumId: referendumId,
            apiParameters: option.chain.externalApis?.governance()?.first?.parameters,
            operationFactory: operationFactory,
            repository: AnyDataProviderRepository(repository),
            operationQueue: operationQueue
        )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { entity in
                chainId == entity.chainId &&
                    referendumId == entity.referendumId
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Did receive error: \(error)")
            }
        }

        let provider = StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        providers[identifier] = WeakWrapper(target: provider)

        return provider
    }
}
