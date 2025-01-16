import Foundation
import Foundation_iOS

struct AssetBalanceDisplayInfo: Hashable {
    enum Icon: Equatable, Hashable {
        case path(String?)
        case url(URL?)

        func getPath() -> String? {
            if case let .path(path) = self {
                return path
            } else {
                return nil
            }
        }

        func getURL() -> URL? {
            if case let .url(URL) = self {
                return URL
            } else {
                return nil
            }
        }
    }

    let displayPrecision: UInt16
    let assetPrecision: Int16
    let symbol: String
    let symbolValueSeparator: String
    let symbolPosition: TokenSymbolPosition
    let icon: Icon?
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
            icon: .path(icon)
        )
    }

    func displayInfo(with chainIcon: URL?) -> AssetBalanceDisplayInfo {
        let iconModel: AssetBalanceDisplayInfo.Icon = if let icon {
            .path(icon)
        } else {
            .url(chainIcon)
        }

        return AssetBalanceDisplayInfo(
            displayPrecision: 5,
            assetPrecision: Int16(bitPattern: precision),
            symbol: symbol,
            symbolValueSeparator: " ",
            symbolPosition: .suffix,
            icon: iconModel
        )
    }
}
