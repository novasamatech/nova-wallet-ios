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
        from _: ParaStkSelectCollatorsViewProtocol?,
        collatorInfo _: CollatorStakingSelectionInfoProtocol
    ) {}
}
