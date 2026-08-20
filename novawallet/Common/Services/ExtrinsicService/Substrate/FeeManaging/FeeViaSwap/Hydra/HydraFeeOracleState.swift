import Foundation
import BigInt

final class HydraFeeOracleState {
    enum FeeCurrency {
        case accepted(BigUInt)
        case notAccepted
    }

    static let maxAge: TimeInterval = 30

    private let routes = InMemoryCache<HydraDx.AssetId, Cached<[HydraRouter.Trade]>>()
    private let feeCurrencies = InMemoryCache<HydraDx.AssetId, Cached<FeeCurrency>>()

    func route(for assetId: HydraDx.AssetId) -> [HydraRouter.Trade]? {
        routes.fetchValue(for: assetId)?.unexpired
    }

    func store(route: [HydraRouter.Trade], for assetId: HydraDx.AssetId) {
        routes.store(value: Cached(value: route), for: assetId)
    }

    func feeCurrency(for assetId: HydraDx.AssetId) -> FeeCurrency? {
        feeCurrencies.fetchValue(for: assetId)?.unexpired
    }

    func store(feeCurrency: FeeCurrency, for assetId: HydraDx.AssetId) {
        feeCurrencies.store(value: Cached(value: feeCurrency), for: assetId)
    }
}

private extension HydraFeeOracleState {
    struct Cached<T> {
        let value: T
        let storedAt: Date

        init(value: T) {
            self.value = value
            storedAt = Date()
        }

        var unexpired: T? {
            Date().timeIntervalSince(storedAt) < HydraFeeOracleState.maxAge ? value : nil
        }
    }
}
