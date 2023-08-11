import Foundation

final class StakingTypeWireframe: StakingTypeWireframeProtocol {
    let state: RelaychainStartStakingStateProtocol

    init(state: RelaychainStartStakingStateProtocol) {
        self.state = state
    }

    func complete(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

    func showNominationPoolsList(from view: ControllerBackedProtocol?) {
        guard let poolListView = StakingSelectPoolViewFactory.createView(state: state) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            poolListView.controller,
            animated: true
        )
    }
}
