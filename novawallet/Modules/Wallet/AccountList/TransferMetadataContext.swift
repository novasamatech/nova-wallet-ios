import Foundation

struct TransferMetadataContext {
    static let receiverBalanceKey = "transfer.metadata.receiver.balance.key"
    static let priceKey = "transfer.metadata.price.key"

    let receiverBalance: Decimal
    let price: Decimal
}

extension TransferMetadataContext {
    private static func decimalFromContext(_ context: [String: String], key: String) -> Decimal {
        guard let stringValue = context[key] else { return .zero }
        return Decimal(string: stringValue) ?? .zero
    }

    init(assetBalance: AssetBalance, precision: Int16, price: Decimal) {
        let free = Decimal
            .fromSubstrateAmount(assetBalance.freeInPlank, precision: precision) ?? .zero
        let reserved = Decimal
            .fromSubstrateAmount(assetBalance.reservedInPlank, precision: precision) ?? .zero

        receiverBalance = free + reserved
        self.price = price
    }

    init(context: [String: String]) {
        receiverBalance = Self.decimalFromContext(context, key: Self.receiverBalanceKey)
        price = Self.decimalFromContext(context, key: Self.priceKey)
    }

    func toContext() -> [String: String] {
        [
            Self.receiverBalanceKey: receiverBalance.stringWithPointSeparator,
            Self.priceKey: price.stringWithPointSeparator
        ]
    }
}
