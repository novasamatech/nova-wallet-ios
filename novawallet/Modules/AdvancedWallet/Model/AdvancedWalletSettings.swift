import Foundation

struct AdvancedNetworkTypeSettings {
    let availableCryptoTypes: [MultiassetCryptoType]
    let selectedCryptoType: MultiassetCryptoType
    let derivationPath: String?
}

enum AdvancedWalletSettings {
    case substrate(settings: AdvancedNetworkTypeSettings)
    case ethereum(derivationPath: String?)
    case combined(substrateSettings: AdvancedNetworkTypeSettings, ethereumDerivationPath: String?)
}
