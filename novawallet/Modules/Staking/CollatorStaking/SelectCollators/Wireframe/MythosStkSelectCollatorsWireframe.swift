import Foundation

final class MythosStkSelectCollatorsWireframe: CollatorStakingSelectWireframe, CollatorStakingSelectWireframeProtocol {
    let state: MythosStakingSharedStateProtocol

    init(state: MythosStakingSharedStateProtocol) {
        self.state = state
    }

    func showFilters(
        from view: ParaStkSelectCollatorsViewProtocol?,
        for sorting: CollatorsSortType,
        delegate: ParaStkCollatorFiltersDelegate
    ) {
        guard let filtersView = ParaStkCollatorFiltersViewFactory.createMythosStakingView(
            for: sorting,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            filtersView.controller,
            animated: true
        )
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
