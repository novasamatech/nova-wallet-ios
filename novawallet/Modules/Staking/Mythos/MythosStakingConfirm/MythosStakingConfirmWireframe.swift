import Foundation

final class MythosStakingConfirmWireframe: MythosStakingConfirmWireframeProtocol {
    let state: MythosStakingSharedStateProtocol

    init(state: MythosStakingSharedStateProtocol) {
        self.state = state
    }
}
