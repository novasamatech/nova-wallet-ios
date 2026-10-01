import UIKit
import UIKit_iOS

final class SubtensorSubnetSelectWireframe: SubtensorSubnetSelectWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    func showDetails(
        from view: SubtensorSubnetSelectViewProtocol?,
        item: SubtensorSubnetListItem,
        delegate: SubtensorSubnetSelectDelegate
    ) {
        let input = SubtensorSubnetDetailsInput(subnet: item.subnet, target: item.target, validator: nil)

        guard let detailsView = SubtensorSubnetDetailsViewFactory.createView(
            for: state,
            input: input,
            host: .picker,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(detailsView.controller, animated: true)
    }

    func showFilters(
        from view: SubtensorSubnetSelectViewProtocol?,
        viewModel: SubtensorSubnetFiltersViewModel,
        onChange: @escaping (SubtensorSubnetFilters) -> Void,
        onApply: @escaping (SubtensorSubnetFilters) -> Void
    ) -> SubtensorSubnetFiltersViewProtocol? {
        guard let view else {
            return nil
        }

        let filtersView = SubtensorSubnetFiltersSheetController(
            viewModel: viewModel,
            onChange: onChange,
            onApply: onApply
        )

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.novaManual)

        filtersView.modalTransitioningFactory = factory
        filtersView.modalPresentationStyle = .custom

        view.controller.present(filtersView, animated: true)

        return filtersView
    }
}
