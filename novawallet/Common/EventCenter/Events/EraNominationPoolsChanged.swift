import Foundation

struct EraNominationPoolsChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processEraNominationPoolsChanged(event: self)
    }
}
