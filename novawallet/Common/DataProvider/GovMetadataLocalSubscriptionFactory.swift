import Foundation
import RobinHood

typealias ReferendumMetadataMapping = [ReferendumIdLocal: ReferendumMetadataLocal]

protocol GovMetadataLocalSubscriptionFactoryProtocol: AnyObject {
    func getMetadataProvider(
        for chain: ChainModel
    ) -> StreamableProvider<ReferendumMetadataLocal>?

    func getMetadataProvider(
        for chain: ChainModel,
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
}

extension GovMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol {
    func getMetadataProvider(
        for chain: ChainModel
    ) -> StreamableProvider<ReferendumMetadataLocal>? {
        guard
            let governanceApi = chain.externalApi?.governance,
            let apiType = GovernanceOffchainApi(rawValue: governanceApi.type) else {
            return nil
        }

        let chainId = chain.chainId
        let url = governanceApi.url

        let identifier = "gov-metadata-preview" + chainId

        if let provider = providers[identifier]?.target as? StreamableProvider<ReferendumMetadataLocal> {
            return provider
        }

        let mapper = ReferendumMetadataMapper()
        let repository = storageFacade.createRepository(
            filter: NSPredicate.referendums(for: chainId),
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper))

        let operationFactory: PolkassemblyOperationFactoryProtocol

        switch apiType {
        case .polkassembly:
            operationFactory = PolkassemblyChainOperationFactory(
                chainId: chainId,
                url: url
            )
        }

        let source = ReferendumsMetadataPreviewProviderSource(
            operationFactory: operationFactory,
            repository: AnyDataProviderRepository(repository),
            operationQueue: operationQueue
        )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
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
        for chain: ChainModel,
        referendumId: ReferendumIdLocal
    ) -> StreamableProvider<ReferendumMetadataLocal>? {
        guard
            let governanceApi = chain.externalApi?.governance,
            let apiType = GovernanceOffchainApi(rawValue: governanceApi.type) else {
            return nil
        }

        let chainId = chain.chainId
        let url = governanceApi.url

        let identifier = "gov-metadata-details" + chainId + String(referendumId)

        if let provider = providers[identifier]?.target as? StreamableProvider<ReferendumMetadataLocal> {
            return provider
        }

        let mapper = ReferendumMetadataMapper()
        let repository = storageFacade.createRepository(
            filter: NSPredicate.referendums(for: chainId),
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper))

        let operationFactory: PolkassemblyOperationFactoryProtocol

        switch apiType {
        case .polkassembly:
            operationFactory = PolkassemblyChainOperationFactory(
                chainId: chainId,
                url: url
            )
        }

        let source = ReferendumMetadataDetailsProviderSource(
            chainId: chainId,
            referendumId: referendumId,
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
