import Foundation

final class GovernanceUnlockConfirmWireframe: GovernanceUnlockConfirmWireframeProtocol {
    func skip(on view: GovernanceUnlockConfirmViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
