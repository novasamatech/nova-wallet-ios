import Foundation

final class SubtensorStakingNotStakedState: SubtensorStakingBaseState {
    override func accept(visitor: SubtensorStakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }
}
