import Foundation

enum KeystoreTag: String, CaseIterable {
    case pincode

    static func secretKeyTagForAddress(_ address: String) -> String { address + "-" + "secretKey" }
    static func entropyTagForAddress(_ address: String) -> String { address + "-" + "entropy" }
    static func deriviationTagForAddress(_ address: String) -> String { address + "-" + "deriv" }
    static func seedTagForAddress(_ address: String) -> String { address + "-" + "seed" }
}

enum KeystoreTagV2: String, CaseIterable {
    case pincode

    static func cloudBackupPasswordTag(for passwordId: String) -> String {
        passwordId + "-" + "cloudPassword"
    }
}

extension KeystoreTagV2 {
    enum Suffix {
        static let substrateSecretKey = "-substrateSecretKey"
        static let ethereumSecretKey = "-ethereumSecretKey"
        static let entropy = "-entropy"
        static let substrateDerivation = "-substrateDeriv"
        static let ethereumDerivation = "-ethereumDeriv"
        static let substrateSeed = "-substrateSeed"
        static let ethereumSeed = "-ethereumSeed"
    }
}
