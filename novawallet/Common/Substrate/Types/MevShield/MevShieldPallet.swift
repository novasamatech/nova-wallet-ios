import Foundation
import SubstrateSdk

enum MevShieldPallet {
    static let name = "MevShield"

    static let encapsulationKeyLength = 1184
    static let maxCiphertextLength = 8192

    static let keyHashLength = 16
    static let kemCiphertextLengthPrefixLength = 2
    static let kemCiphertextLength = 1088
    static let aeadNonceLength = 24
    static let aeadTagLength = 16

    static var nextKeyPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "NextKey")
    }

    static var submitEncryptedPath: CallCodingPath {
        CallCodingPath(moduleName: name, callName: "submit_encrypted")
    }

    static func ciphertextLength(forPlaintextLength plaintextLength: Int) -> Int {
        keyHashLength + kemCiphertextLengthPrefixLength + kemCiphertextLength + aeadNonceLength +
            plaintextLength + aeadTagLength
    }
}
