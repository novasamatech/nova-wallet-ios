import Foundation

class CollatorStakingSelectWireframe {
    func close(view: ParaStkSelectCollatorsViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
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
}
