import Foundation

struct MetamaskChain: Codable {
    struct NativeCurrency: Codable {
        let name: String
        let symbol: String // 2-6 characters long
        let decimals: Int
    }

    let chainId: String // A 0x-prefixed hexadecimal string
    let chainName: String
    let nativeCurrency: NativeCurrency
    let rpcUrls: [String]
    let blockExplorerUrls: [String]?
    let iconUrls: [String]?
}

extension MetamaskChain {
    var assetDisplayInfo: AssetBalanceDisplayInfo {
        let icons = iconUrls?.compactMap { URL(string: $0) }

        return AssetBalanceDisplayInfo(
            displayPrecision: 5,
            assetPrecision: Int16(nativeCurrency.decimals),
            symbol: nativeCurrency.symbol,
            symbolValueSeparator: " ",
            symbolPosition: .suffix,
            icon: icons?.first
        )
    }
}
