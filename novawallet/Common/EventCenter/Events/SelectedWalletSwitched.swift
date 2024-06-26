import Foundation

struct SelectedWalletSwitched: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processSelectedWalletChanged(event: self)
    }
}
