import Foundation
import Foundation_iOS

final class SubtensorPortfolioWireframe: SubtensorPortfolioWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) { self.state = state }

    func showPosition(
        from view: SubtensorPortfolioViewProtocol?,
        group: SubtensorPortfolioGroup,
        state _: Multistaking.SubtensorStakingState,
        commonData: SubtensorStakingCommonData
    ) {
        guard let positionView = SubtensorPositionViewFactory.createView(
            for: state,
            group: group,
            commonData: commonData
        ) else { return }
        view?.controller.navigationController?.pushViewController(positionView.controller, animated: true)
    }

    func showAddPosition(from view: SubtensorPortfolioViewProtocol?) {
        guard let setup = SubtensorStakingSetupViewFactory.createView(
            for: state,
            initialPosition: nil
        ) else { return }
        let navigation = ImportantFlowViewFactory.createNavigation(from: setup.controller)
        view?.controller.presentWithCardLayout(navigation, animated: true)
    }
}
