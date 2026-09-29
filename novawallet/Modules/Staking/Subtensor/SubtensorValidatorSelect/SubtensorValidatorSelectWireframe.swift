import UIKit

final class SubtensorValidatorSelectWireframe: ValidatorSelectWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    func complete(from view: SubtensorValidatorSelectViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
