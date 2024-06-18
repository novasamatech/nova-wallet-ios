import Foundation

struct WalletNameChanged: EventProtocol {
    let isSelectedWallet: Bool

    func accept(visitor: EventVisitorProtocol) {
        visitor.processWalletNameChanged(event: self)
    }
}
