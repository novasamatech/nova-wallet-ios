import Foundation

final class SubtensorUnstakeConfirmWireframe: SubtensorUnstakeConfirmWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }
}
