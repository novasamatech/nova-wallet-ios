import Foundation

final class ParaStkSelectCollatorsWireframe: CollatorStakingSelectWireframe, CollatorStakingSelectWireframeProtocol {
    let sharedState: ParachainStakingSharedStateProtocol

    init(sharedState: ParachainStakingSharedStateProtocol) {
        self.sharedState = sharedState
    }

    func showFilters(
        from view: CollatorStakingSelectViewProtocol?,
        for sorting: CollatorsSortType,
        delegate: CollatorStakingSelectFiltersDelegate
    ) {
        guard let filtersView = CollatorStakingSelectFiltersViewFactory.createParachainStakingView(
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
            let searchView = CollatorStakingSelectSearchViewFactory.createParachainStakingView(
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
        from view: CollatorStakingSelectViewProtocol?,
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
