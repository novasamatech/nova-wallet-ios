import Foundation

final class ParaStkCollatorsSearchWireframe: CollatorStakingSelectSearchWireframe,
    CollatorStakingSelectSearchWireframeProtocol {
    let sharedState: ParachainStakingSharedStateProtocol

    init(sharedState: ParachainStakingSharedStateProtocol) {
        self.sharedState = sharedState
    }

    func showCollatorInfo(
        from view: CollatorStakingSelectSearchViewProtocol?,
        collatorInfo: CollatorStakingSelectionInfoProtocol
    ) {
        guard let infoView = CollatorStakingInfoViewFactory.createParachainStakingView(
            for: sharedState,
            collatorInfo: collatorInfo
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(infoView.controller, animated: true)
    }
}
