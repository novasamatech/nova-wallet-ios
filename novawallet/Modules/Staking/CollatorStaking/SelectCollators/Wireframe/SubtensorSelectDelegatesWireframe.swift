import Foundation

final class SubtensorSelectDelegatesWireframe: CollatorStakingSelectWireframe, CollatorStakingSelectWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    func showFilters(
        from view: CollatorStakingSelectViewProtocol?,
        for sorting: CollatorsSortType,
        delegate: CollatorStakingSelectFiltersDelegate
    ) {
        guard let filtersView = CollatorStakingSelectFiltersViewFactory.createSubtensorStakingView(
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
            let searchView = CollatorStakingSelectSearchViewFactory.createSubtensorStakingView(
                for: state,
                delegates: collatorsInfo,
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
        guard let infoView = CollatorStakingInfoViewFactory.createSubtensorStakingView(
            for: state,
            delegateInfo: collatorInfo
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(infoView.controller, animated: true)
    }
}
