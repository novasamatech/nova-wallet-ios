import Foundation

final class MythosCollatorsSearchWireframe: CollatorStakingSelectSearchWireframe, CollatorStakingSelectSearchWireframeProtocol {
    let sharedState: MythosStakingSharedStateProtocol

    init(sharedState: MythosStakingSharedStateProtocol) {
        self.sharedState = sharedState
    }

    func showCollatorInfo(
        from view: CollatorStakingSelectSearchViewProtocol?,
        collatorInfo: CollatorStakingSelectionInfoProtocol
    ) {
        guard let infoView = CollatorStakingInfoViewFactory.createMythosStakingView(
            for: sharedState,
            collatorInfo: collatorInfo
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(infoView.controller, animated: true)
    }
}
