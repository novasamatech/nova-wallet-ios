import Foundation
import Operation_iOS

protocol PriceProviderFactoryProtocol {
    func getPriceStreamableProvider(
        for priceId: AssetModel.PriceId,
        currency: Currency
    ) -> StreamableProvider<PriceData>

    func getAllPricesStreamableProvider(
        currency: Currency
    ) -> StreamableProvider<PriceData>

    func getPriceHistoryProvider(
        for priceId: AssetModel.PriceId,
        currency: Currency
    ) -> AnySingleValueProvider<PriceHistory>
}

class PriceProviderFactory {
    static let shared = PriceProviderFactory(
        chainRegistry: ChainRegistryFacade.sharedRegistry,
        storageFacade: SubstrateDataStorageFacade.shared,
        operationQueue: OperationManagerFacade.sharedDefaultQueue,
        logger: Logger.shared
    )

    private var providers: [String: WeakWrapper] = [:]
    private var sources: [String: AnyStreamableSource<PriceData>] = [:]

    let storageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let priceProvider: PriceIdProviderProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.storageFacade = storageFacade
        self.operationQueue = operationQueue
        self.logger = logger
        priceProvider = PriceIdProvider(chainRegistry: chainRegistry)
    }

    private func clearIfNeeded() {
        providers = providers.filter { $0.value.target != nil }
    }
}

extension PriceProviderFactory: PriceProviderFactoryProtocol {
    func getPriceStreamableProvider(
        for priceId: AssetModel.PriceId,
        currency: Currency
    ) -> StreamableProvider<PriceData> {
        clearIfNeeded()

        func localIdentifier(for priceId: AssetModel.PriceId, currencyId: String) -> String {
            "coingecko_price_\(priceId)_\(currencyId)"
        }

        let identifier = localIdentifier(for: priceId, currencyId: currency.coingeckoId)

        if let provider = providers[identifier]?.target as? StreamableProvider<PriceData> {
            return provider
        }

        let source: AnyStreamableSource<PriceData> = self.source(for: currency)

        let mapper = PriceDataMapper()
        let filter = NSPredicate.price(for: priceId, currencyId: currency.id)
        let repository: CoreDataRepository<PriceData, CDPrice> = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
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
            guard let error else {
                return
            }
            self?.logger.error("Did receive error: \(error)")
        }

        let provider = StreamableProvider<PriceData>(
            source: source,
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        providers[identifier] = WeakWrapper(target: provider)

        return provider
    }

    func getAllPricesStreamableProvider(
        currency: Currency
    ) -> StreamableProvider<PriceData> {
        clearIfNeeded()
        let cacheKey = currency.coingeckoId

        if let provider = providers[cacheKey]?.target as? StreamableProvider<PriceData> {
            return provider
        }

        let source: AnyStreamableSource<PriceData> = self.source(for: currency)

        let mapper = PriceDataMapper()
        let filter = NSPredicate.prices(for: currency.id)
        let repository: CoreDataRepository<PriceData, CDPrice> = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )
        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { entity in
                entity.currency == currency.id
            }
        )

        observable.start { [weak self] error in
            if let error {
                self?.logger.error("Did receive error: \(error)")
            }
        }

        let provider = StreamableProvider<PriceData>(
            source: source,
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        providers[cacheKey] = WeakWrapper(target: provider)

        return provider
    }

    func getPriceHistoryProvider(
        for priceId: AssetModel.PriceId,
        currency: Currency
    ) -> AnySingleValueProvider<PriceHistory> {
        clearIfNeeded()

        let cacheId = "coingecko_price_history_\(priceId)_\(currency.id)"

        if let provider = providers[cacheId]?.target as? SingleValueProvider<PriceHistory> {
            return AnySingleValueProvider(provider)
        }

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = storageFacade.createRepository()

        let source = CoingeckoPriceHistoryProviderSource(
            priceId: priceId,
            currency: currency,
            period: .allTime,
            operationFactory: CoingeckoOperationFactory(),
            logger: logger
        )

        let singleValueProvider = SingleValueProvider(
            targetIdentifier: cacheId,
            source: AnySingleValueProviderSource(source),
            repository: AnyDataProviderRepository(repository)
        )

        providers[cacheId] = WeakWrapper(target: singleValueProvider)

        return AnySingleValueProvider(singleValueProvider)
    }
}

private extension PriceProviderFactory {
    func source(for currency: Currency) -> AnyStreamableSource<PriceData> {
        let cacheKey = currency.coingeckoId
        guard let cached = sources[cacheKey] else {
            let mapper = PriceDataMapper()
            let filter = NSPredicate.prices(for: currency.id)
            let repository: CoreDataRepository<PriceData, CDPrice> = storageFacade.createRepository(
                filter: filter,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )
            let coingecko = CoingeckoStreamableSource(
                priceIdsObservable: priceProvider.priceIdsObservable,
                currency: currency,
                repository: AnyDataProviderRepository(repository),
                operationQueue: operationQueue
            )
            let source = AnyStreamableSource(coingecko)
            sources[cacheKey] = source
            return source
        }
        return cached
    }
}
