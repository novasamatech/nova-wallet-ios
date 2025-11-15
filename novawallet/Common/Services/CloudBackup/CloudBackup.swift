import Foundation

enum CloudBackup {
    static let walletsFilename = "wallets.novawallet"

    static var containerId: String {
        #if F_RELEASE
            "iCloud.io.novasamatech.novawallet.Documents"
        #else
            "iCloud.io.novasamatech.novawallet.dev.Documents"
        #endif
    }
}
