import Foundation

struct BalanceContext {
    let free: Decimal
    let reserved: Decimal
    let frozen: Decimal
    let external: [ExternalBalanceAssetGroupId: Decimal]
    let price: Decimal
    let priceChange: Decimal
    let priceId: Int?
    let balanceLocks: [AssetLock]
}

extension BalanceContext {
    var externalTotal: Decimal { external.values.reduce(0) { $0 + $1 } }
    var total: Decimal { free + reserved + externalTotal }
    var locked: Decimal { reserved + frozen + externalTotal }
    var available: Decimal { free >= frozen ? free - frozen : 0.0 }
}
