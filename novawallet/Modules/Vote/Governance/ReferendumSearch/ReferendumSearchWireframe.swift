import Foundation

final class ReferendumSearchWireframe: ReferendumSearchWireframeProtocol {
    private let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func finish(from view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
