import Foundation
import RobinHood

protocol PriceProviderFactoryProtocol {
    func getPriceStreamableProvider(
        for priceId: AssetModel.PriceId,
        currency: Currency
    ) -> StreamableProvider<PriceData>

    func getAllPricesStreamableProvider(
        for priceIds: [AssetModel.PriceId],
        currency: Currency
    ) -> StreamableProvider<PriceData>
}

class PriceProviderFactory {
    static let shared = PriceProviderFactory(
        storageFacade: SubstrateDataStorageFacade.shared,
        operationQueue: OperationManagerFacade.sharedDefaultQueue,
        logger: Logger.shared
    )

    private var providers: [String: WeakWrapper] = [:]

    let storageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(storageFacade: StorageFacadeProtocol, operationQueue: OperationQueue, logger: LoggerProtocol) {
        self.storageFacade = storageFacade
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func clearIfNeeded() {
        providers = providers.filter { $0.value.target != nil }
    }

    static func localIdentifier(for priceId: AssetModel.PriceId, currencyId: String) -> String {
        "coingecko_price_\(priceId)_\(currencyId)"
    }
}

extension PriceProviderFactory: PriceProviderFactoryProtocol {
    func getPriceStreamableProvider(
        for priceId: AssetModel.PriceId,
        currency: Currency
    ) -> StreamableProvider<PriceData> {
        clearIfNeeded()

        let identifier = Self.localIdentifier(for: priceId, currencyId: currency.coingeckoId)

        if let provider = providers[identifier]?.target as? StreamableProvider<PriceData> {
            return provider
        }

        let mapper = PriceDataMapper()
        let filter = NSPredicate.price(for: priceId, currencyId: currency.id)
        let repository: CoreDataRepository<PriceData, CDPrice> = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let source = CoingeckoStreamableSource(
            priceIds: [priceId],
            currency: currency,
            repository: AnyDataProviderRepository(repository),
            operationQueue: operationQueue
        )

        let expectedIdentifier = PriceData.createIdentifier(for: priceId, currencyId: currency.id)
        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { entity in
                entity.identifier == expectedIdentifier
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Did receive error: \(error)")
            }
        }

        let provider = StreamableProvider<PriceData>(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        providers[identifier] = WeakWrapper(target: provider)

        return provider
    }

    func getAllPricesStreamableProvider(
        for priceIds: [AssetModel.PriceId],
        currency: Currency
    ) -> StreamableProvider<PriceData> {
        clearIfNeeded()

        let coingeckoId = currency.coingeckoId
        let fullKey = priceIds.joined() + "\(coingeckoId)"
        let cacheKey = fullKey.data(using: .utf8)?.sha256().toHex() ?? fullKey

        if let provider = providers[cacheKey]?.target as? StreamableProvider<PriceData> {
            return provider
        }

        let mapper = PriceDataMapper()
        let filter = NSPredicate.prices(for: currency.id)
        let repository: CoreDataRepository<PriceData, CDPrice> = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let source = CoingeckoStreamableSource(
            priceIds: priceIds,
            currency: currency,
            repository: AnyDataProviderRepository(repository),
            operationQueue: operationQueue
        )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { entity in
                entity.currency == currency.id
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Did receive error: \(error)")
            }
        }

        let provider = StreamableProvider<PriceData>(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        providers[cacheKey] = WeakWrapper(target: provider)

        return provider
    }
}
