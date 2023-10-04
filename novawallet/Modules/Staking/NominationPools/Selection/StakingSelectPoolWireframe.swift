import Foundation

final class StakingSelectPoolWireframe: StakingSelectPoolWireframeProtocol {
    let state: RelaychainStartStakingStateProtocol

    init(state: RelaychainStartStakingStateProtocol) {
        self.state = state
    }

    func complete(from view: ControllerBackedProtocol?) {
        if let amountView: StakingSetupAmountViewProtocol = view?.controller.navigationController?.findTopView() {
            view?.controller.navigationController?.popToViewController(
                amountView.controller,
                animated: true
            )
        }
    }

    func showSearch(
        from view: ControllerBackedProtocol?,
        delegate: StakingSelectPoolDelegate,
        selectedPoolId: NominationPools.PoolId?
    ) {
        guard let view = view,
              let searchView = NominationPoolSearchViewFactory.createView(
                  state: state,
                  delegate: delegate,
                  selectedPoolId: selectedPoolId
              ) else {
            return
        }

        view.controller.navigationController?.pushViewController(searchView.controller, animated: true)
    }
}
