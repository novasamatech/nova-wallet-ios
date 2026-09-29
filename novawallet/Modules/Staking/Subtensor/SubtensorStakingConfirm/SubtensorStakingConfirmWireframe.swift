import Foundation

final class SubtensorStakingConfirmWireframe: SubtensorStakingConfirmWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }
}
