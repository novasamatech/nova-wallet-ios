import Foundation

struct EvmNewHeadReceived: EventProtocol {
    let chainId: ChainModel.Id

    func accept(visitor: EventVisitorProtocol) {
        visitor.processEvmNewHead(event: self)
    }
}
