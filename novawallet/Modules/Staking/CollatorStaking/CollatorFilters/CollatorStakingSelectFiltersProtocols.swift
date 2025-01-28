protocol CollatorStakingSelectFiltersViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: CollatorStakingSelectFiltersViewModel)
}

protocol CollatorStakingSelectFiltersPresenterProtocol: AnyObject {
    func setup()
    func applyFilter()
    func resetFilter()
    func selectSorting(at index: Int)
}

protocol CollatorStakingSelectFiltersWireframeProtocol: AnyObject {
    func close(view: CollatorStakingSelectFiltersViewProtocol?)
}

protocol CollatorStakingSelectFiltersDelegate: AnyObject {
    func didReceiveCollator(sorting: CollatorsSortType)
}
