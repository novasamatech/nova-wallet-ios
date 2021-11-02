import Foundation
import SubstrateSdk

enum MultiassetCryptoType: UInt8, CaseIterable {
    case sr25519
    case ed25519
    case substrateEcdsa
    case ethereumEcdsa
}

extension MultiassetCryptoType {
    static var substrateTypeList: [MultiassetCryptoType] {
        [.sr25519, .ed25519, .substrateEcdsa]
    }

    var utilsType: SubstrateSdk.CryptoType {
        switch self {
        case .sr25519:
            return .sr25519
        case .ed25519:
            return .ed25519
        case .substrateEcdsa, .ethereumEcdsa:
            return .ecdsa
        }
    }
}
