import Foundation
import Foundation_iOS

final class SubtensorSubnetFiltersPresenter {
    weak var view: SubtensorSubnetFiltersViewProtocol?
    weak var delegate: SubtensorSubnetFiltersDelegate?

    let wireframe: SubtensorSubnetFiltersWireframeProtocol
    let viewModelFactory: SubtensorSubnetFiltersViewModelFactory

    private var filters: SubtensorSubnetFilters

    init(
        filters: SubtensorSubnetFilters,
        wireframe: SubtensorSubnetFiltersWireframeProtocol,
        viewModelFactory: SubtensorSubnetFiltersViewModelFactory,
        delegate: SubtensorSubnetFiltersDelegate,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.filters = filters
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.delegate = delegate
        self.localizationManager = localizationManager
    }
}

private extension SubtensorSubnetFiltersPresenter {
    func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(
            filters: filters,
            count: delegate?.countSubnets(matching: filters),
            locale: selectedLocale
        )

        view?.didReceive(viewModel: viewModel)
    }
}

extension SubtensorSubnetFiltersPresenter: SubtensorSubnetFiltersPresenterProtocol {
    func setup() {
        provideViewModel()
    }

    func setHidesThinPools(_ value: Bool) {
        filters.hideThinPools = value

        provideViewModel()
    }

    func apply() {
        let filters = filters
        let delegate = delegate

        wireframe.close(view: view) {
            delegate?.didReceiveSubnet(filters: filters)
        }
    }
}

extension SubtensorSubnetFiltersPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideViewModel()
        }
    }
}
