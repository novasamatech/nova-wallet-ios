import Foundation

struct WalletNameChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processWalletNameChanged(event: self)
    }
}
