import Foundation

struct FeeMetadataContext {
    static let feeBalanceKey = "fee.metadata.fee.balance.key"
    static let feeAssetPriceKey = "fee.metadata.fee.asset.price.key"

    let feeAssetBalance: Decimal
    let feeAssetPrice: Decimal
}

extension FeeMetadataContext {
    private static func decimalFromContext(_ context: [String: String], key: String) -> Decimal {
        guard let stringValue = context[key] else { return .zero }
        return Decimal(string: stringValue) ?? .zero
    }

    init(assetBalance: AssetBalance, precision: Int16, feeAssetPrice: Decimal) {
        let free = Decimal
            .fromSubstrateAmount(assetBalance.freeInPlank, precision: precision) ?? .zero
        let reserved = Decimal
            .fromSubstrateAmount(assetBalance.reservedInPlank, precision: precision) ?? .zero

        feeAssetBalance = free + reserved
        self.feeAssetPrice = feeAssetPrice
    }

    init(context: [String: String]) {
        feeAssetBalance = Self.decimalFromContext(context, key: Self.feeBalanceKey)
        feeAssetPrice = Self.decimalFromContext(context, key: Self.feeAssetPriceKey)
    }

    func toContext() -> [String: String] {
        [
            Self.feeBalanceKey: feeAssetBalance.stringWithPointSeparator,
            Self.feeAssetPriceKey: feeAssetPrice.stringWithPointSeparator
        ]
    }
}
