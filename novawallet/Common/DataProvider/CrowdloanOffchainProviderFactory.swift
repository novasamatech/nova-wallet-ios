import Foundation
import RobinHood

protocol CrowdloanOffchainProviderFactoryProtocol {
    func getExternalContributionProvider(
        for accountId: AccountId,
        chain: ChainModel
    ) throws -> AnySingleValueProvider<[ExternalContribution]>
}

class CrowdloanOffchainProviderFactory: CrowdloanOffchainProviderFactoryProtocol {
    private var providers: [String: WeakWrapper] = [:]

    let storageFacade: StorageFacadeProtocol
    let paraIdOperationFactory: ParaIdOperationFactoryProtocol

    init(storageFacade: StorageFacadeProtocol, paraIdOperationFactory: ParaIdOperationFactoryProtocol) {
        self.storageFacade = storageFacade
        self.paraIdOperationFactory = paraIdOperationFactory
    }

    func getExternalContributionProvider(
        for accountId: AccountId,
        chain: ChainModel
    ) throws -> AnySingleValueProvider<[ExternalContribution]> {
        let identifier = "ext_cont" + accountId.toHex() + chain.chainId

        if let provider = providers[identifier]?.target as? SingleValueProvider<[ExternalContribution]> {
            return AnySingleValueProvider(provider)
        }

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            storageFacade.createRepository()

        let externalSources = ExternalContributionSourcesFactory.createExternalSources(
            for: chain.chainId,
            paraIdOperationFactory: paraIdOperationFactory
        )

        let source = ExternalContributionDataProviderSource(
            accountId: accountId,
            chain: chain,
            children: externalSources
        )

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
