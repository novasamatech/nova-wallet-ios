import Foundation

struct HideZeroBalancesChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processHideZeroBalances(event: self)
    }
}
