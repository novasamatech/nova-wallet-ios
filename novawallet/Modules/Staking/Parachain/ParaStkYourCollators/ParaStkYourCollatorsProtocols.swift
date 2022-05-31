protocol ParaStkYourCollatorsViewProtocol: ControllerBackedProtocol {
    func reload(state: ParaStkYourCollatorsState)
}

protocol ParaStkYourCollatorsPresenterProtocol: AnyObject {
    func setup()
    func retry()
    func manageCollators()
    func selectCollator(viewModel: CollatorSelectionViewModel)
}

protocol ParaStkYourCollatorsInteractorInputProtocol: AnyObject {}

protocol ParaStkYourCollatorsInteractorOutputProtocol: AnyObject {}

protocol ParaStkYourCollatorsWireframeProtocol: AnyObject {}
