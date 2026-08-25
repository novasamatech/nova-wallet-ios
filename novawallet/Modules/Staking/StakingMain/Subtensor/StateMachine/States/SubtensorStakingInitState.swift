import Foundation

final class SubtensorStakingInitState: SubtensorStakingBaseState {
    override func accept(visitor: SubtensorStakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }
}
