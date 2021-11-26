import Foundation

struct AdvancedNetworkTypeSettings {
    let cryptoType: MultiassetCryptoType
    let derivationPath: String?
}

enum AdvancedWalletSettings {
    case substrate(settings: AdvancedNetworkTypeSettings)
    case ethereum(settings: AdvancedNetworkTypeSettings)
    case combined(substrate: AdvancedNetworkTypeSettings, ethereum: AdvancedNetworkTypeSettings)
}
