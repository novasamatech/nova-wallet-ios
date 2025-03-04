import Foundation

final class MythosStkUnstakeConfirmWireframe: MythosStkUnstakeConfirmWireframeProtocol {
    let state: MythosStakingSharedStateProtocol

    init(state: MythosStakingSharedStateProtocol) {
        self.state = state
    }
}
