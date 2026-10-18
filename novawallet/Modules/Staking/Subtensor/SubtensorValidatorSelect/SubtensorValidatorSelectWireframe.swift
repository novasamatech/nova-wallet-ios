import UIKit

final class SubtensorValidatorSelectWireframe: SubtensorValidatorSelectWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    func showFilters(
        from view: SubtensorValidatorSelectViewProtocol?,
        applied: SubtensorValidatorFilters,
        onApply: @escaping (SubtensorValidatorFilters) -> Void
    ) {
        let filters = SubtensorValidatorFiltersViewFactory.createView(applied: applied, onApply: onApply)
        view?.controller.navigationController?.pushViewController(filters.controller, animated: true)
    }

    func complete(from view: SubtensorValidatorSelectViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
