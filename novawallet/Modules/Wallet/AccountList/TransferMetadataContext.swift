import Foundation

struct TransferMetadataContext {
    static let receiverBalanceKey = "transfer.metadata.receiver.balance.key"
    static let transferAssetPriceKey = "transfer.metadata.transfer.asset.price.key"

    let receiverBalance: Decimal
    let transferAssetPrice: Decimal
}

extension TransferMetadataContext {
    private static func decimalFromContext(_ context: [String: String], key: String) -> Decimal {
        guard let stringValue = context[key] else { return .zero }
        return Decimal(string: stringValue) ?? .zero
    }

    init(assetBalance: AssetBalance, precision: Int16, transferAssetPrice: Decimal) {
        let free = Decimal
            .fromSubstrateAmount(assetBalance.freeInPlank, precision: precision) ?? .zero
        let reserved = Decimal
            .fromSubstrateAmount(assetBalance.reservedInPlank, precision: precision) ?? .zero

        receiverBalance = free + reserved
        self.transferAssetPrice = transferAssetPrice
    }

    init(context: [String: String]) {
        receiverBalance = Self.decimalFromContext(context, key: Self.receiverBalanceKey)
        transferAssetPrice = Self.decimalFromContext(context, key: Self.transferAssetPriceKey)
    }

    func toContext() -> [String: String] {
        [
            Self.receiverBalanceKey: receiverBalance.stringWithPointSeparator,
            Self.transferAssetPriceKey: transferAssetPrice.stringWithPointSeparator
        ]
    }
}
