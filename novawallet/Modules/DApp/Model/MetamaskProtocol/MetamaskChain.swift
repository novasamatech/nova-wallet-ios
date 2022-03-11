import Foundation

struct MetamaskChain: Codable {
    struct NativeCurrency: Codable {
        let name: String
        let symbol: String // 2-6 characters long
        let decimals: Int16
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

    static var etheremChain: MetamaskChain {
        MetamaskChain(
            chainId: "0x1",
            chainName: "Ethereum Mainnet",
            nativeCurrency: NativeCurrency(name: "Ether", symbol: "ETH", decimals: 18),
            rpcUrls: ["https://mainnet.infura.io/v3/6b7733290b9a4156bf62a4ba105b76ec"],
            blockExplorerUrls: nil,
            iconUrls: nil
        )
    }

    func appending(iconUrl: String) -> MetamaskChain {
        let iconUrls = (self.iconUrls ?? []) + [iconUrl]

        return MetamaskChain(
            chainId: chainId,
            chainName: chainName,
            nativeCurrency: nativeCurrency,
            rpcUrls: rpcUrls,
            blockExplorerUrls: blockExplorerUrls,
            iconUrls: iconUrls
        )
    }
}
