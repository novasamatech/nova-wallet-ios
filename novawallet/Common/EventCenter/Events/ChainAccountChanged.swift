import Foundation

struct ChainAccountChanged: EventProtocol {
    let method: AccountChangeType

    func accept(visitor: EventVisitorProtocol) {
        visitor.processChainAccountChanged(event: self)
    }
}
