import Foundation
import Foundation_iOS

final class SubtensorPositionWireframe: SubtensorPositionWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) { self.state = state }

    func showStake(from view: SubtensorPositionViewProtocol?, position: SubtensorStakingPosition?) {
        guard let setup = SubtensorStakingSetupViewFactory.createView(
            for: state,
            initialPosition: position
        ) else { return }
        let navigation = ImportantFlowViewFactory.createNavigation(from: setup.controller)
        view?.controller.presentWithCardLayout(navigation, animated: true)
    }

    func showUnstake(from view: SubtensorPositionViewProtocol?, position: SubtensorStakingPosition?) {
        guard let position, let setup = SubtensorUnstakeSetupViewFactory.createView(
            for: state,
            netuid: position.netuid
        ) else { return }
        let navigation = ImportantFlowViewFactory.createNavigation(from: setup.controller)
        view?.controller.presentWithCardLayout(navigation, animated: true)
    }

    func showValidatorInfo(from view: SubtensorPositionViewProtocol?, delegate: SubtensorDelegate) {
        let info = SubtensorDelegateSelectionInfo(delegate: delegate, minStake: 0)
        guard let infoView = CollatorStakingInfoViewFactory.createSubtensorStakingView(
            for: state,
            delegateInfo: info
        ) else { return }
        view?.controller.navigationController?.pushViewController(infoView.controller, animated: true)
    }
}
