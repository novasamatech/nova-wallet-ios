protocol ParaStkCollatorsSearchViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: ParaStkCollatorsSearchViewModel?)
}

protocol ParaStkCollatorsSearchPresenterProtocol: AnyObject {
    func setup()
    func selectCollator(at index: Int)
    func search(text: String)
    func presentCollatorInfo(at index: Int)
}

protocol ParaStkCollatorsSearchInteractorInputProtocol: AnyObject {}

protocol ParaStkCollatorsSearchInteractorOutputProtocol: AnyObject {}

protocol ParaStkCollatorsSearchWireframeProtocol: AnyObject {
    func complete(on view: ParaStkCollatorsSearchViewProtocol?)
    func showCollatorInfo(from view: ParaStkCollatorsSearchViewProtocol?, collatorInfo: CollatorSelectionInfo)
}
