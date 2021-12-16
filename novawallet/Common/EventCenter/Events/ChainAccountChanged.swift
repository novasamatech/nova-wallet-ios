import Foundation

struct ChainAccountChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processChainAccountChanged(event: self)
    }
}
