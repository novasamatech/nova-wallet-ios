import Foundation

struct AdvancedExportData {
    enum ChainType {
        case substrate(AdvancedExportChainData)
        case ethereum(AdvancedExportChainData)
    }

    let chains: [ChainType]
}

struct AdvancedExportChainData {
    let name: String
    let availableOptions: [SecretSource]
    let derivationPath: String?
    let cryptoType: MultiassetCryptoType
}