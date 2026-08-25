import Foundation

final class SubtensorSelectSearchWireframe: CollatorStakingSelectSearchWireframe,
    CollatorStakingSelectSearchWireframeProtocol {
    let sharedState: SubtensorStakingSharedStateProtocol

    init(sharedState: SubtensorStakingSharedStateProtocol) {
        self.sharedState = sharedState
    }

    func showCollatorInfo(
        from view: CollatorStakingSelectSearchViewProtocol?,
        collatorInfo: CollatorStakingSelectionInfoProtocol
    ) {
        guard let infoView = CollatorStakingInfoViewFactory.createSubtensorStakingView(
            for: sharedState,
            delegateInfo: collatorInfo
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(infoView.controller, animated: true)
    }
}
