import Foundation
import RobinHood

protocol PriceProviderFactoryProtocol {
    func getPriceProvider(
        for priceId: AssetModel.PriceId,
        currency: Currency
    ) -> AnySingleValueProvider<PriceData>
    func getPriceListProvider(
        for priceIds: [AssetModel.PriceId],
        currency: Currency
    ) -> AnySingleValueProvider<[PriceData]>
}

class PriceProviderFactory {
    static let shared = PriceProviderFactory(storageFacade: SubstrateDataStorageFacade.shared)

    private var providers: [String: WeakWrapper] = [:]

    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    private func clearIfNeeded() {
        providers = providers.filter { $0.value.target != nil }
    }

    static func localIdentifier(for priceId: AssetModel.PriceId, currencyId: String) -> String {
        "coingecko_price_\(priceId)_\(currencyId)"
    }
}

extension PriceProviderFactory: PriceProviderFactoryProtocol {
    func getPriceProvider(for priceId: AssetModel.PriceId, currency: Currency) -> AnySingleValueProvider<PriceData> {
        clearIfNeeded()

        let identifier = Self.localIdentifier(for: priceId, currencyId: currency.coingeckoId)

        if let provider = providers[identifier]?.target as? SingleValueProvider<PriceData> {
            return AnySingleValueProvider(provider)
        }

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            storageFacade.createRepository()

        let source = CoingeckoPriceSource(priceId: priceId, currency: currency)

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

    func getPriceListProvider(
        for priceIds: [AssetModel.PriceId],
        currency: Currency
    ) -> AnySingleValueProvider<[PriceData]> {
        clearIfNeeded()

        let coingeckoId = currency.coingeckoId
        let fullKey = priceIds.joined() + "\(coingeckoId)"
        let cacheKey = fullKey.data(using: .utf8)?.sha256().toHex() ?? fullKey

        if let provider = providers[cacheKey]?.target as? SingleValueProvider<[PriceData]> {
            return AnySingleValueProvider(provider)
        }

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            storageFacade.createRepository()

        let source = CoingeckoPriceListSource(priceIds: priceIds, currency: currency)

        let databaseIdentifier = "coingecko_price_list_\(coingeckoId)_identifier"

        let trigger: DataProviderEventTrigger = [.onAddObserver, .onInitialization]
        let provider = SingleValueProvider(
            targetIdentifier: databaseIdentifier,
            source: AnySingleValueProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger
        )

        providers[cacheKey] = WeakWrapper(target: provider)

        return AnySingleValueProvider(provider)
    }
}
