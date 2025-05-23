import Foundation

extension SecureSessionManager {
    static func createForWalletMigration() -> SecureSessionManager {
        SecureSessionManager(
            auth: WalletMigrationParams.encryptionAuth,
            salt: WalletMigrationParams.encryptionSalt
        )
    }
}
