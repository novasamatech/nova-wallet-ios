protocol ReferendumsFiltersViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: ReferendumsFilterViewModel)
}

protocol ReferendumsFiltersPresenterProtocol: AnyObject {
    func setup()
    func select(filter: ReferendumsFilter)
    func applyFilter()
    func resetFilter()
}

protocol ReferendumsFiltersWireframeProtocol: AnyObject {
    func close(_ view: ReferendumsFiltersViewProtocol?)
}
