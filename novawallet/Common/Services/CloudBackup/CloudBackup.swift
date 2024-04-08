import Foundation

enum CloudBackup {
    static let walletsFilename = "wallets.novawallet"

    static var containerId: String {
        "iCloud.io.novafoundation.novawallet.dev.Documents"
    }

    static let requiredCloudSize: UInt64 = 2 * 1024 * 1024
}
