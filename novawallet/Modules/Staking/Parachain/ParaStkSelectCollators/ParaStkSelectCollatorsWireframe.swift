import Foundation

final class ParaStkSelectCollatorsWireframe: ParaStkSelectCollatorsWireframeProtocol {
    let sharedState: ParachainStakingSharedState

    init(sharedState: ParachainStakingSharedState) {
        self.sharedState = sharedState
    }

    func close(view: ParaStkSelectCollatorsViewProtocol?) {
        view?.controller.navigationController?.popToRootViewController(animated: true)
    }

    func showFilters(
        from view: ParaStkSelectCollatorsViewProtocol?,
        for sorting: CollatorsSortType,
        delegate: ParaStkCollatorFiltersDelegate
    ) {
        guard let filtersView = ParaStkCollatorFiltersViewFactory.createView(
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
        for collatorsInfo: [CollatorSelectionInfo],
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
        collatorInfo: CollatorSelectionInfo
    ) {
        guard let infoView = ParaStkCollatorInfoViewFactory.createView(
            for: sharedState,
            collatorInfo: collatorInfo
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(infoView.controller, animated: true)
    }
}
