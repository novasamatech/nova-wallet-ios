import Foundation

final class SubtensorConfirmWireframe: SubtensorConfirmWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }
}
