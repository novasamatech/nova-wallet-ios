import Foundation
import Foundation_iOS

final class SubtensorPortfolioWireframe: SubtensorPortfolioWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) { self.state = state }

    func showPosition(from view: SubtensorPortfolioViewProtocol?, group: SubtensorPortfolioGroup) {
        guard let positionView = SubtensorPositionViewFactory.createView(for: state, group: group) else { return }
        view?.controller.navigationController?.pushViewController(positionView.controller, animated: true)
    }

    func showAddPosition(from view: SubtensorPortfolioViewProtocol?) {
        presentSubtensorEarnInfo(from: view, chainAsset: state.stakingOption.chainAsset)
    }

    func close(from view: SubtensorPortfolioViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else { return }

        let tabBarController = navigationController.tabBarController

        guard tabBarController?.selectedViewController === navigationController else {
            navigationController.popToRootViewController(animated: false)
            return
        }

        SubtensorModalStack.dismiss(above: tabBarController, animated: false) {
            navigationController.popToRootViewController(animated: true)
        }
    }
}
