import Foundation

struct NetworkEnabledChanged: EventProtocol {
    let chainId: ChainModel.Id
    let enabled: Bool

    func accept(visitor: EventVisitorProtocol) {
        visitor.processNetworkEnableChanged(event: self)
    }
}
