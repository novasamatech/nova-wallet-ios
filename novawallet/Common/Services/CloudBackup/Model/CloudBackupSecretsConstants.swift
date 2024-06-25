import Foundation

extension CloudBackup {
    enum SecretsConstants {
        static let sr25519NonceSize = 32
        static let sr25519PrivateKeySize = 32
        static var sr25519Size: Int {
            Self.sr25519NonceSize + sr25519PrivateKeySize
        }
    }
}
