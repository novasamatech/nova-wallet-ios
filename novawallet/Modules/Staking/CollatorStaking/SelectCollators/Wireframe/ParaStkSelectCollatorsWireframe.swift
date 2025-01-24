import Foundation

final class ParaStkSelectCollatorsWireframe: CollatorStakingSelectWireframe, CollatorStakingSelectWireframeProtocol {
    let sharedState: ParachainStakingSharedStateProtocol

    init(sharedState: ParachainStakingSharedStateProtocol) {
        self.sharedState = sharedState
    }

    func showSearch(
        from view: ParaStkSelectCollatorsViewProtocol?,
        for collatorsInfo: [CollatorStakingSelectionInfoProtocol],
        delegate: ParaStkSelectCollatorsDelegate
    ) {
        guard
            let searchView = ParaStkCollatorsSearchViewFactory.createView(
                for: sharedState,
                collators: collatorsInfo,
                delegate: delegate
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            searchView.controller,
            animated: true
        )
    }

    func showCollatorInfo(
        from view: ParaStkSelectCollatorsViewProtocol?,
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
