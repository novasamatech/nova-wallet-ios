import UIKit

final class SubtensorSubnetSelectWireframe: SubtensorSubnetSelectWireframeProtocol {
    let state: SubtensorSharedStateProtocol

    init(state: SubtensorSharedStateProtocol) {
        self.state = state
    }

    func showDetails(
        from view: SubtensorSubnetSelectViewProtocol?,
        item: SubtensorSubnetListItem,
        abandonTracker: AnalyticsAbandonTracker?,
        delegate: SubtensorSubnetSelectDelegate
    ) {
        let input = SubtensorSubnetDetailsInput(subnet: item.subnet, target: item.target, validator: nil)

        guard let detailsView = SubtensorSubnetDetailsViewFactory.createView(
            for: state,
            input: input,
            host: .picker,
            abandonTracker: abandonTracker,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(detailsView.controller, animated: true)
    }

    func showFilters(
        from view: SubtensorSubnetSelectViewProtocol?,
        filters: SubtensorSubnetFilters,
        delegate: SubtensorSubnetFiltersDelegate
    ) {
        guard let filtersView = SubtensorSubnetFiltersViewFactory.createView(
            chainAsset: state.stakingOption.chainAsset,
            filters: filters,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.present(filtersView.controller, animated: true)
    }
}
