import Foundation

final class StakingSelectPoolWireframe: StakingSelectPoolWireframeProtocol {
    let state: RelaychainStartStakingStateProtocol

    init(state: RelaychainStartStakingStateProtocol) {
        self.state = state
    }

    func complete(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

    func showSearch(from view: ControllerBackedProtocol?, delegate: StakingSelectPoolDelegate) {
        guard let view = view,
              let searchView = NominationPoolSearchViewFactory.createView(state: state, delegate: delegate) else {
            return
        }

        view.controller.navigationController?.pushViewController(searchView.controller, animated: true)
    }
}
