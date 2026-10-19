import UIKit

final class SubtensorValidatorSelectWireframe: SubtensorValidatorSelectWireframeProtocol {
    let state: SubtensorSharedStateProtocol

    init(state: SubtensorSharedStateProtocol) {
        self.state = state
    }

    func showFilters(
        from view: SubtensorValidatorSelectViewProtocol?,
        applied: SubtensorValidatorFilters,
        delegate: SubtensorValidatorFiltersDelegate
    ) {
        let filters = SubtensorValidatorFiltersViewFactory.createView(applied: applied, delegate: delegate)
        view?.controller.navigationController?.pushViewController(filters.controller, animated: true)
    }

    func complete(from view: SubtensorValidatorSelectViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
