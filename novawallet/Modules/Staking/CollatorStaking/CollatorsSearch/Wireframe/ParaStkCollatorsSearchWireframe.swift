import Foundation

final class ParaStkCollatorsSearchWireframe: CollatorStakingSelectSearchWireframe,
    CollatorStakingSelectSearchWireframeProtocol {
    let sharedState: ParachainStakingSharedStateProtocol

    init(sharedState: ParachainStakingSharedStateProtocol) {
        self.sharedState = sharedState
    }

    func showCollatorInfo(
        from view: ParaStkCollatorsSearchViewProtocol?,
        collatorInfo: CollatorStakingSelectionInfoProtocol
    ) {
        guard let infoView = ParaStkCollatorInfoViewFactory.createParachainStakingView(
            for: sharedState,
            collatorInfo: collatorInfo
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(infoView.controller, animated: true)
    }
}
