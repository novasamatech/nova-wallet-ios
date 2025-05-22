import Foundation
@testable import novawallet

final class MockWalletMigrationDelegate {
    private(set) var lastMessage: WalletMigrationMessage?
}

extension MockWalletMigrationDelegate: WalletMigrationDelegate {
    func didReceiveMigration(message: WalletMigrationMessage) {
        lastMessage = message
    }
}
