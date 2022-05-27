protocol ParaStkSelectCollatorsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: CollatorSelectionScreenViewModel)
}

protocol ParaStkSelectCollatorsPresenterProtocol: AnyObject {
    func setup()
    func presentCollatorInfo(at index: Int)
    func presentSearch()
    func presenterFilters()
    func clearFilters()
}

protocol ParaStkSelectCollatorsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol ParaStkSelectCollatorsInteractorOutputProtocol: AnyObject {
    func didReceiveCollators(result: Result<[CollatorSelectionInfo], Error>)
}

protocol ParaStkSelectCollatorsWireframeProtocol: AlertPresentable, ErrorPresentable {}
