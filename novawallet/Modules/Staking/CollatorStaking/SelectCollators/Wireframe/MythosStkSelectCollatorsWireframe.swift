import Foundation

final class MythosStkSelectCollatorsWireframe: CollatorStakingSelectWireframe, CollatorStakingSelectWireframeProtocol {
    let state: MythosStakingSharedStateProtocol

    init(state: MythosStakingSharedStateProtocol) {
        self.state = state
    }

    func showFilters(
        from view: CollatorStakingSelectViewProtocol?,
        for sorting: CollatorsSortType,
        delegate: CollatorStakingSelectFiltersDelegate
    ) {
        guard let filtersView = CollatorStakingSelectFiltersViewFactory.createMythosStakingView(
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
        from view: CollatorStakingSelectViewProtocol?,
        for collatorsInfo: [CollatorStakingSelectionInfoProtocol],
        delegate: CollatorStakingSelectDelegate
    ) {
        guard
            let searchView = CollatorStakingSelectSearchViewFactory.createMythosStakingView(
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
        from view: CollatorStakingSelectViewProtocol?,
        collatorInfo: CollatorStakingSelectionInfoProtocol
    ) {
        guard let infoView = CollatorStakingInfoViewFactory.createMythosStakingView(
            for: state,
            collatorInfo: collatorInfo
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(infoView.controller, animated: true)
    }
}
