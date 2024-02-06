import Foundation

extension HydraDx {
    static var omnipoolAssets: StorageCodingPath {
        StorageCodingPath(moduleName: Self.omniPoolModule, itemName: "Assets")
    }

    static var dynamicFees: StorageCodingPath {
        StorageCodingPath(moduleName: Self.dynamicFeesModule, itemName: "AssetFee")
    }

    static var feeCurrencies: StorageCodingPath {
        StorageCodingPath(moduleName: Self.multiTxPaymentModule, itemName: "AcceptedCurrencies")
    }

    static var accountFeeCurrency: StorageCodingPath {
        StorageCodingPath(moduleName: Self.multiTxPaymentModule, itemName: "AccountCurrencyMap")
    }

    static var referralLinkedAccount: StorageCodingPath {
        StorageCodingPath(moduleName: Self.referralsModule, itemName: "LinkedAccounts")
    }
}
