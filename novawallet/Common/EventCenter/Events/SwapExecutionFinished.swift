import Foundation

struct SwapExecutionFinished: EventProtocol {
    let chainIds: Set<ChainModel.Id>

    func accept(visitor: EventVisitorProtocol) {
        visitor.processSwapExecutionFinished(event: self)
    }
}
