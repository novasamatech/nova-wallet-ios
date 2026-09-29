import Foundation
import UIKit

final class SubtensorPositionWireframe: SubtensorPositionWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    func showAddStake(from view: SubtensorPositionViewProtocol?, position: SubtensorStakingPosition) {
        guard let setupView = SubtensorStakingSetupViewFactory.createAddStakeView(for: state, position: position) else {
            return
        }

        presentFlow(setupView, from: view)
    }

    func showBuyMore(from view: SubtensorPositionViewProtocol?, position: SubtensorStakingPosition) {
        guard let setupView = SubtensorStakingSetupViewFactory.createBuyMoreView(for: state, position: position) else {
            return
        }

        presentFlow(setupView, from: view)
    }

    func showUnstake(from view: SubtensorPositionViewProtocol?, netuid: UInt16) {
        guard let unstakeView = SubtensorUnstakeSetupViewFactory.createView(for: state, netuid: netuid) else {
            return
        }

        presentFlow(unstakeView, from: view)
    }

    func popToPortfolio(from view: SubtensorPositionViewProtocol?) {
        guard
            let controller = view?.controller,
            let navigationController = controller.navigationController,
            let index = navigationController.viewControllers.firstIndex(of: controller),
            index > 0 else {
            return
        }

        navigationController.popToViewController(navigationController.viewControllers[index - 1], animated: true)
    }
}

private extension SubtensorPositionWireframe {
    func presentFlow(_ flowView: ControllerBackedProtocol, from view: SubtensorPositionViewProtocol?) {
        let navigation = ImportantFlowViewFactory.createNavigation(from: flowView.controller)

        view?.controller.presentWithCardLayout(navigation, animated: true)
    }
}
