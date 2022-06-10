import Foundation

struct BlockTimeChanged {
    let chainId: ChainModel.Id
}

extension BlockTimeChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processBlockTimeChanged(event: self)
    }
}
