import Foundation

final class ReferendumsFiltersPresenter {
    weak var view: ReferendumsFiltersViewProtocol?
    weak var delegate: ReferendumsFiltersDelegate?
    let wireframe: ReferendumsFiltersWireframeProtocol
    let initialFilter: ReferendumsFilter
    private var selectedFilter: ReferendumsFilter

    init(
        wireframe: ReferendumsFiltersWireframeProtocol,
        initialFilter: ReferendumsFilter,
        delegate: ReferendumsFiltersDelegate?
    ) {
        self.wireframe = wireframe
        self.initialFilter = initialFilter
        selectedFilter = initialFilter
        self.delegate = delegate
    }

    private func provideViewModel() {
        let canReset = selectedFilter != .all
        let canApply = selectedFilter != initialFilter
        view?.didReceive(viewModel: .init(
            selectedFilter: selectedFilter,
            canReset: canReset,
            canApply: canApply
        ))
    }
}

extension ReferendumsFiltersPresenter: ReferendumsFiltersPresenterProtocol {
    func setup() {
        provideViewModel()
    }

    func select(filter: ReferendumsFilter) {
        selectedFilter = filter
        provideViewModel()
    }

    func applyFilter() {
        delegate?.didUpdate(filter: selectedFilter)
        wireframe.close(view)
    }

    func resetFilter() {
        selectedFilter = .all
        provideViewModel()
    }
}
