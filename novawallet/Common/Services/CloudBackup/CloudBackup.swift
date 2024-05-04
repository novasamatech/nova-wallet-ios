import Foundation

enum CloudBackup {
    static let walletsFilename = "wallets.novawallet"

    static var containerId: String {
        "iCloud.io.novafoundation.novawallet.dev.Documents"
    }

    static let requiredCloudSize: UInt64 = 10 * 1024 * 1024

    static let storageCheckTimeout: TimeInterval = 15
    static let backupSaveTimeout: TimeInterval = 15
}
