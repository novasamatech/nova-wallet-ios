import Foundation

extension HydraDx {
    static var dynamicFeesPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.dynamicFeesModule, itemName: "AssetFee")
    }

    static var feeCurrenciesPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.multiTxPaymentModule, itemName: "AcceptedCurrencies")
    }

    static var accountFeeCurrencyPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.multiTxPaymentModule, itemName: "AccountCurrencyMap")
    }

    static var referralLinkedAccountPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.referralsModule, itemName: "LinkedAccounts")
    }
}
