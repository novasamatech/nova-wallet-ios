import Foundation
import UIKit

final class SubtensorPositionWireframe: SubtensorPositionWireframeProtocol, SubtensorCallerPopping {
    let state: SubtensorSharedStateProtocol

    init(state: SubtensorSharedStateProtocol) {
        self.state = state
    }

    func showClaimRewards(from view: SubtensorPositionViewProtocol?, model: SubtensorClaimRewardsModel) {
        guard let claimView = SubtensorClaimRewardsViewFactory.createView(for: state, model: model) else {
            return
        }

        presentFlow(claimView, from: view)
    }

    func showAddStake(from view: SubtensorPositionViewProtocol?, position: SubtensorPosition) {
        guard let setupView = SubtensorStakeSetupViewFactory.createAddStakeView(for: state, position: position) else {
            return
        }

        presentFlow(setupView, from: view)
    }

    func showBuyMore(from view: SubtensorPositionViewProtocol?, position: SubtensorPosition) {
        guard let setupView = SubtensorStakeSetupViewFactory.createBuyMoreView(for: state, position: position) else {
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
        popToCaller(from: view)
    }
}

private extension SubtensorPositionWireframe {
    func presentFlow(_ flowView: ControllerBackedProtocol, from view: SubtensorPositionViewProtocol?) {
        let navigation = ImportantFlowViewFactory.createNavigation(from: flowView.controller)

        view?.controller.presentWithCardLayout(navigation, animated: true)
    }
}
