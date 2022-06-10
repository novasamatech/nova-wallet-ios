protocol ParaStkCollatorFiltersViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: ParaStkCollatorFiltersViewModel)
}

protocol ParaStkCollatorFiltersPresenterProtocol: AnyObject {
    func setup()
    func applyFilter()
    func resetFilter()
    func selectSorting(at index: Int)
}

protocol ParaStkCollatorFiltersWireframeProtocol: AnyObject {
    func close(view: ParaStkCollatorFiltersViewProtocol?)
}

protocol ParaStkCollatorFiltersDelegate: AnyObject {
    func didReceiveCollator(sorting: CollatorsSortType)
}
