import Foundation

struct WalletMigrationEvent: EventProtocol {
    let message: WalletMigrationMessage

    func accept(visitor: EventVisitorProtocol) {
        visitor.processWalletMigration(event: self)
    }
}
