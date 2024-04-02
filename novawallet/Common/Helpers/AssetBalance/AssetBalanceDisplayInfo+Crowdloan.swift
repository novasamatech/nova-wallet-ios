import Foundation

extension AssetBalanceDisplayInfo {
    static func fromCrowdloan(info: CrowdloanDisplayInfo) -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: 5,
            assetPrecision: 5,
            symbol: info.token,
            symbolValueSeparator: " ",
            symbolPosition: .suffix,
            icon: URL(string: info.icon)
        )
    }
}
