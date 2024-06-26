import Foundation

enum CloudBackup {
    static let walletsFilename = "wallets.novawallet"

    static var containerId: String {
        #if F_RELEASE
            "iCloud.io.novafoundation.novawallet.Documents"
        #else
            "iCloud.io.novafoundation.novawallet.dev.Documents"
        #endif
    }
}
