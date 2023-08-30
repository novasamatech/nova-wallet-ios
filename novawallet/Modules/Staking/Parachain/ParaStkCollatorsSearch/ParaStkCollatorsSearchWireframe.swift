import Foundation

final class ParaStkCollatorsSearchWireframe: ParaStkCollatorsSearchWireframeProtocol {
    let sharedState: ParachainStakingSharedStateProtocol

    init(sharedState: ParachainStakingSharedStateProtocol) {
        self.sharedState = sharedState
    }

    func complete(on view: ParaStkCollatorsSearchViewProtocol?) {
        let navigationController = view?.controller.navigationController
        let viewControllers = navigationController?.viewControllers ?? []

        if let setupScreenController = viewControllers.first { $0 is ParaStkStakeSetupViewProtocol } {
            navigationController?.popToViewController(setupScreenController, animated: true)
        } else {
            view?.controller.navigationController?.popToRootViewController(animated: true)
        }
    }

    func showCollatorInfo(
        from view: ParaStkCollatorsSearchViewProtocol?,
        collatorInfo: CollatorSelectionInfo
    ) {
        guard let infoView = ParaStkCollatorInfoViewFactory.createView(
            for: sharedState,
            collatorInfo: collatorInfo
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(infoView.controller, animated: true)
    }
}
