import Foundation

struct EraStakersInfoChanged: EventProtocol {
    let chainId: ChainModel.Id

    func accept(visitor: EventVisitorProtocol) {
        visitor.processEraStakersInfoChanged(event: self)
    }
}
