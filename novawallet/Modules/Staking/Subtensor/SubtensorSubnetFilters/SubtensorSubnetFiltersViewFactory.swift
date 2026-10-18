import Foundation
import Foundation_iOS
import UIKit_iOS

enum SubtensorSubnetFiltersViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        filters: SubtensorSubnetFilters,
        delegate: SubtensorSubnetFiltersDelegate
    ) -> SubtensorSubnetFiltersViewProtocol? {
        let presenter = SubtensorSubnetFiltersPresenter(
            filters: filters,
            wireframe: SubtensorSubnetFiltersWireframe(),
            viewModelFactory: SubtensorSubnetFiltersViewModelFactory(chainAsset: chainAsset),
            delegate: delegate,
            localizationManager: LocalizationManager.shared
        )

        let view = SubtensorSubnetFiltersViewController(presenter: presenter)

        presenter.view = view

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.novaManual)

        view.modalTransitioningFactory = factory
        view.modalPresentationStyle = .custom

        return view
    }
}
