protocol ParaStkYourCollatorsViewProtocol: ControllerBackedProtocol {
    func reload(state: ParaStkYourCollatorsState)
}

protocol ParaStkYourCollatorsPresenterProtocol: AnyObject {
    func setup()
    func retry()
    func manageCollators()
    func selectCollator(viewModel: CollatorSelectionViewModel)
}

protocol ParaStkYourCollatorsInteractorInputProtocol: AnyObject {
    func setup()
    func retry()
}

protocol ParaStkYourCollatorsInteractorOutputProtocol: AnyObject {
    func didReceiveCollators(result: Result<[CollatorSelectionInfo], Error>)
    func didReceiveDelegator(result: Result<ParachainStaking.Delegator?, Error>)
}

protocol ParaStkYourCollatorsWireframeProtocol: AnyObject {}
