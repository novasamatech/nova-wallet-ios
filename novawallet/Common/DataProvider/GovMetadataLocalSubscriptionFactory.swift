import Foundation
import RobinHood

typealias ReferendumMetadataMapping = [ReferendumIdLocal: ReferendumMetadataLocal]

protocol GovMetadataLocalSubscriptionFactoryProtocol: AnyObject {
    func getMetadataProvider(
        for chain: ChainModel
    ) -> AnySingleValueProvider<ReferendumMetadataMapping>
}

final class GovMetadataLocalSubscriptionFactory {
    private var providers: [String: WeakWrapper] = [:]

    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }
}

extension GovMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol {
    func getMetadataProvider(
        for chain: ChainModel
    ) -> AnySingleValueProvider<ReferendumMetadataMapping> {
        let identifier = "gov-metadata" + chain.chainId

        if let provider = providers[identifier]?.target as? SingleValueProvider<ReferendumMetadataMapping> {
            return AnySingleValueProvider(provider)
        }

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            storageFacade.createRepository()

        let source = Gov2MetadataProviderSource()

        let trigger: DataProviderEventTrigger = [.onAddObserver, .onInitialization]
        let provider = SingleValueProvider(
            targetIdentifier: identifier,
            source: AnySingleValueProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger
        )

        providers[identifier] = WeakWrapper(target: provider)

        return AnySingleValueProvider(provider)
    }
}
