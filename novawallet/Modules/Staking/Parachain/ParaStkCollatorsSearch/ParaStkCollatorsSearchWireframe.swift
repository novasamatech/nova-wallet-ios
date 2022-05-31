import Foundation

final class ParaStkCollatorsSearchWireframe: ParaStkCollatorsSearchWireframeProtocol {
    let sharedState: ParachainStakingSharedState

    init(sharedState: ParachainStakingSharedState) {
        self.sharedState = sharedState
    }

    func complete(on view: ParaStkCollatorsSearchViewProtocol?) {
        view?.controller.navigationController?.popToRootViewController(animated: true)
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
