import Foundation
import BigInt

struct TransferMetadataContext {
    static let receiverAssetBalanceKey = "transfer.metadata.receiver.asset.balance.key"
    static let receiverUtilityBalanceKey = "transfer.metadata.receiver.utility.balance.key"
    static let senderUtilityBalanceKey = "transfer.metadata.sender.utility.balance.key"
    static let transferAssetPriceKey = "transfer.metadata.transfer.asset.price.key"
    static let assetMinBalanceKey = "transfer.metadata.transfer.asset.min.balance.key"
    static let utilityMinBalanceKey = "transfer.metadata.transfer.utility.min.balance.key"

    let receiverAssetBalance: Decimal
    let receiverUtilityBalance: Decimal?
    let senderUtilityBalance: Decimal?
    let transferAssetPrice: Decimal
    let assetMinBalance: Decimal
    let utilityMinBalance: Decimal?

    var utilityMatchesAsset: Bool { utilityMinBalance == nil }
}

extension TransferMetadataContext {
    private static func decimalFromContext(_ context: [String: String], key: String) -> Decimal {
        guard let stringValue = context[key] else { return .zero }
        return Decimal(string: stringValue) ?? .zero
    }

    static func totalBalance(from assetBalance: AssetBalance, precision: Int16) -> Decimal {
        let free = Decimal
            .fromSubstrateAmount(assetBalance.freeInPlank, precision: precision) ?? .zero
        let reserved = Decimal
            .fromSubstrateAmount(assetBalance.reservedInPlank, precision: precision) ?? .zero

        return free + reserved
    }

    init(
        receiverAssetBalance: AssetBalance,
        assetMinBalance: BigUInt,
        assetPrecision: Int16,
        transferAssetPrice: Decimal,
        receiverUtilityBalance: AssetBalance?,
        senderUtilityBalance: AssetBalance?,
        utilityMinBalance: BigUInt?,
        utilityPrecision: Int16
    ) {
        self.receiverAssetBalance = Self.totalBalance(
            from: receiverAssetBalance,
            precision: assetPrecision
        )

        self.transferAssetPrice = transferAssetPrice

        self.senderUtilityBalance = senderUtilityBalance.map {
            Self.totalBalance(from: $0, precision: utilityPrecision)
        }

        self.receiverUtilityBalance = receiverUtilityBalance.map {
            Self.totalBalance(from: $0, precision: utilityPrecision)
        }

        self.assetMinBalance = Decimal.fromSubstrateAmount(assetMinBalance, precision: assetPrecision) ??
            .zero

        if let balance = utilityMinBalance {
            self.utilityMinBalance = Decimal.fromSubstrateAmount(balance, precision: utilityPrecision) ??
                .zero
        } else {
            self.utilityMinBalance = nil
        }
    }

    init(context: [String: String]) {
        receiverAssetBalance = Self.decimalFromContext(context, key: Self.receiverAssetBalanceKey)
        transferAssetPrice = Self.decimalFromContext(context, key: Self.transferAssetPriceKey)
        assetMinBalance = Self.decimalFromContext(context, key: Self.assetMinBalanceKey)

        if context[Self.receiverUtilityBalanceKey] != nil {
            receiverUtilityBalance = Self.decimalFromContext(context, key: Self.receiverUtilityBalanceKey)
        } else {
            receiverUtilityBalance = nil
        }

        if context[Self.senderUtilityBalanceKey] != nil {
            senderUtilityBalance = Self.decimalFromContext(context, key: Self.senderUtilityBalanceKey)
        } else {
            senderUtilityBalance = nil
        }

        if context[Self.utilityMinBalanceKey] != nil {
            utilityMinBalance = Self.decimalFromContext(context, key: Self.utilityMinBalanceKey)
        } else {
            utilityMinBalance = nil
        }
    }

    func toContext() -> [String: String] {
        var dict = [
            Self.receiverAssetBalanceKey: receiverAssetBalance.stringWithPointSeparator,
            Self.transferAssetPriceKey: transferAssetPrice.stringWithPointSeparator,
            Self.assetMinBalanceKey: assetMinBalance.stringWithPointSeparator
        ]

        if let balance = senderUtilityBalance {
            dict[Self.senderUtilityBalanceKey] = balance.stringWithPointSeparator
        }

        if let balance = receiverUtilityBalance {
            dict[Self.receiverUtilityBalanceKey] = balance.stringWithPointSeparator
        }

        if let balance = utilityMinBalance {
            dict[Self.utilityMinBalanceKey] = balance.stringWithPointSeparator
        }

        return dict
    }
}
