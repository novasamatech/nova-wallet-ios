import Foundation

final class MythosStkSelectCollatorsWireframe: CollatorStakingSelectWireframe, CollatorStakingSelectWireframeProtocol {
    let state: MythosStakingSharedStateProtocol

    init(state: MythosStakingSharedStateProtocol) {
        self.state = state
    }

    func showSearch(
        from _: ParaStkSelectCollatorsViewProtocol?,
        for _: [CollatorStakingSelectionInfoProtocol],
        delegate _: ParaStkSelectCollatorsDelegate
    ) {}

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
