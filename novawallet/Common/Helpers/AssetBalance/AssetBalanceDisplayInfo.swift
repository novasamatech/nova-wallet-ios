import Foundation
import SoraFoundation

struct AssetBalanceDisplayInfo: Hashable {
    let displayPrecision: UInt16
    let assetPrecision: Int16
    let symbol: String
    let symbolValueSeparator: String
    let symbolPosition: TokenSymbolPosition
    let icon: URL?
}

extension AssetBalanceDisplayInfo {
    static func usd() -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: 2,
            assetPrecision: 2,
            symbol: "$",
            symbolValueSeparator: "",
            symbolPosition: .prefix,
            icon: nil
        )
    }

    static func units(for assetPrecision: Int16) -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: 5,
            assetPrecision: assetPrecision,
            symbol: "",
            symbolValueSeparator: "",
            symbolPosition: .prefix,
            icon: nil
        )
    }

    static func from(currency: Currency) -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: 2,
            assetPrecision: 2,
            symbol: currency.symbol ?? currency.code,
            symbolValueSeparator: currency.symbol != nil ? "" : " ",
            symbolPosition: .prefix,
            icon: nil
        )
    }
}

extension AssetModel {
    var displayInfo: AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: 5,
            assetPrecision: Int16(bitPattern: precision),
            symbol: symbol,
            symbolValueSeparator: " ",
            symbolPosition: .suffix,
            icon: icon
        )
    }

    func displayInfo(with chainIcon: URL) -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: 5,
            assetPrecision: Int16(bitPattern: precision),
            symbol: symbol,
            symbolValueSeparator: " ",
            symbolPosition: .suffix,
            icon: icon ?? chainIcon
        )
    }
}
