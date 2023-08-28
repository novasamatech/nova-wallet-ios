import Foundation

final class StakingSelectPoolWireframe: StakingSelectPoolWireframeProtocol {
    let state: RelaychainStartStakingStateProtocol

    init(state: RelaychainStartStakingStateProtocol) {
        self.state = state
    }

    func complete(from view: ControllerBackedProtocol?) {
        if let stakingSetupAmountView: StakingSetupAmountViewProtocol = view?.controller.navigationController?.findTopView() {
            view?.controller.navigationController?.popToViewController(
                stakingSetupAmountView.controller,
                animated: true
            )
        }
    }

    func showSearch(from view: ControllerBackedProtocol?, delegate: StakingSelectPoolDelegate) {
        guard let view = view,
              let searchView = NominationPoolSearchViewFactory.createView(state: state, delegate: delegate) else {
            return
        }

        view.controller.navigationController?.pushViewController(searchView.controller, animated: true)
    }
}
