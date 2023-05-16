import Foundation

struct BalanceContext {
    static let freeKey = "account.balance.free.key"
    static let reservedKey = "account.balance.reserved.key"
    static let frozen = "account.balance.frozen.key"
    static let priceKey = "account.balance.price.key"
    static let priceChangeKey = "account.balance.price.change.key"
    static let priceIdKey = "account.balance.price.id.key"
    static let balanceLocksKey = "account.balance.locks.key"
    static let crowdloans = "account.balance.crowdloan.key"

    let free: Decimal
    let reserved: Decimal
    let frozen: Decimal
    let crowdloans: Decimal
    let price: Decimal
    let priceChange: Decimal
    let priceId: Int?
    let balanceLocks: [AssetLock]
}

extension BalanceContext {
    var total: Decimal { free + reserved + crowdloans }
    var locked: Decimal { reserved + frozen + crowdloans }
    var available: Decimal { free >= frozen ? free - frozen : 0.0 }
}

extension BalanceContext {
    init(context: [String: String]) {
        free = Self.parseContext(key: BalanceContext.freeKey, context: context)
        reserved = Self.parseContext(key: BalanceContext.reservedKey, context: context)
        frozen = Self.parseContext(key: BalanceContext.frozen, context: context)

        price = Self.parseContext(key: BalanceContext.priceKey, context: context)
        priceChange = Self.parseContext(key: BalanceContext.priceChangeKey, context: context)
        priceId = context[BalanceContext.priceIdKey].flatMap { Int($0) }

        crowdloans = Self.parseContext(key: BalanceContext.crowdloans, context: context)
        balanceLocks = Self.parseJSONContext(key: BalanceContext.balanceLocksKey, context: context)
    }

    func toContext() -> [String: String] {
        let locksStringRepresentation: String = {
            guard let locksJSON = try? JSONEncoder().encode(balanceLocks) else {
                return ""
            }

            return String(data: locksJSON, encoding: .utf8) ?? ""
        }()

        var dict = [
            BalanceContext.freeKey: free.stringWithPointSeparator,
            BalanceContext.reservedKey: reserved.stringWithPointSeparator,
            BalanceContext.frozen: frozen.stringWithPointSeparator,
            BalanceContext.crowdloans: crowdloans.stringWithPointSeparator,
            BalanceContext.priceKey: price.stringWithPointSeparator,
            BalanceContext.priceChangeKey: priceChange.stringWithPointSeparator,
            BalanceContext.balanceLocksKey: locksStringRepresentation
        ]

        if let priceId = priceId {
            dict[BalanceContext.priceIdKey] = String(priceId)
        }

        return dict
    }

    private static func parseContext(key: String, context: [String: String]) -> Decimal {
        if let stringValue = context[key] {
            return Decimal(string: stringValue) ?? .zero
        } else {
            return .zero
        }
    }

    private static func parseJSONContext(key: String, context: [String: String]) -> [AssetLock] {
        guard let locksStringRepresentation = context[key] else { return [] }

        guard let JSONData = locksStringRepresentation.data(using: .utf8) else {
            return []
        }

        let balanceLocks = try? JSONDecoder().decode(
            [AssetLock].self,
            from: JSONData
        )

        return balanceLocks ?? []
    }
}

extension BalanceContext {
    func byChangingAssetBalance(_ assetBalance: AssetBalance, precision: Int16) -> BalanceContext {
        let free = Decimal
            .fromSubstrateAmount(assetBalance.freeInPlank, precision: precision) ?? .zero
        let reserved = Decimal
            .fromSubstrateAmount(assetBalance.reservedInPlank, precision: precision) ?? .zero
        let frozen = Decimal
            .fromSubstrateAmount(assetBalance.frozenInPlank, precision: precision) ?? .zero

        return BalanceContext(
            free: free,
            reserved: reserved,
            frozen: frozen,
            crowdloans: crowdloans,
            price: price,
            priceChange: priceChange,
            priceId: priceId,
            balanceLocks: balanceLocks
        )
    }

    func byChangingBalanceLocks(
        _ updatedLocks: [AssetLock]
    ) -> BalanceContext {
        BalanceContext(
            free: free,
            reserved: reserved,
            frozen: frozen,
            crowdloans: crowdloans,
            price: price,
            priceChange: priceChange,
            priceId: priceId,
            balanceLocks: updatedLocks
        )
    }

    func byChangingPrice(_ newPrice: Decimal, newPriceChange: Decimal, newPriceId: Int?) -> BalanceContext {
        BalanceContext(
            free: free,
            reserved: reserved,
            frozen: frozen,
            crowdloans: crowdloans,
            price: newPrice,
            priceChange: newPriceChange,
            priceId: newPriceId,
            balanceLocks: balanceLocks
        )
    }

    func byChangingCrowdloans(_ newCrowdloans: Decimal) -> BalanceContext {
        BalanceContext(
            free: free,
            reserved: reserved,
            frozen: frozen,
            crowdloans: newCrowdloans,
            price: price,
            priceChange: priceChange,
            priceId: priceId,
            balanceLocks: balanceLocks
        )
    }
}
