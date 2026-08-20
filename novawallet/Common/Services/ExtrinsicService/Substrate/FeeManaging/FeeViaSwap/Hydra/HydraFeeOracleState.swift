import Foundation
import BigInt

final class HydraFeeOracleState {
    enum FeeCurrency {
        case accepted(BigUInt)
        case notAccepted
    }

    // Router.Routes and AcceptedCurrencies only change by governance, so reusing them across a
    // burst of estimates costs nothing. The oracle entries and the block they are aged against
    // stay uncached and pinned to one block hash.
    static let maxAge: TimeInterval = 30

    private let mutex = NSLock()
    private var routes: [HydraDx.AssetId: (value: [HydraRouter.Trade], at: Date)] = [:]
    private var feeCurrencies: [HydraDx.AssetId: (value: FeeCurrency, at: Date)] = [:]

    func route(for assetId: HydraDx.AssetId) -> [HydraRouter.Trade]? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return Self.unexpired(routes[assetId])
    }

    func store(route: [HydraRouter.Trade], for assetId: HydraDx.AssetId) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        routes[assetId] = (value: route, at: Date())
    }

    func feeCurrency(for assetId: HydraDx.AssetId) -> FeeCurrency? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return Self.unexpired(feeCurrencies[assetId])
    }

    func store(feeCurrency: FeeCurrency, for assetId: HydraDx.AssetId) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        feeCurrencies[assetId] = (value: feeCurrency, at: Date())
    }
}

private extension HydraFeeOracleState {
    static func unexpired<T>(_ entry: (value: T, at: Date)?) -> T? {
        guard let entry, Date().timeIntervalSince(entry.at) < maxAge else {
            return nil
        }

        return entry.value
    }
}
