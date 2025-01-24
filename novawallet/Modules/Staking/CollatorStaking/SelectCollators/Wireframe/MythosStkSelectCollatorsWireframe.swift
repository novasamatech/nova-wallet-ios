import Foundation

final class MythosStkSelectCollatorsWireframe: CollatorStakingSelectWireframe, CollatorStakingSelectWireframeProtocol {
    let state: MythosStakingSharedStateProtocol

    init(state: MythosStakingSharedStateProtocol) {
        self.state = state
    }

    func showSearch(
        from view: ParaStkSelectCollatorsViewProtocol?,
        for collatorsInfo: [CollatorStakingSelectionInfoProtocol],
        delegate: ParaStkSelectCollatorsDelegate
    ) {
        guard
            let searchView = ParaStkCollatorsSearchViewFactory.createMythosStakingView(
                for: state,
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
        guard let infoView = ParaStkCollatorInfoViewFactory.createMythosStakingView(
            for: state,
            collatorInfo: collatorInfo
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(infoView.controller, animated: true)
    }
}
