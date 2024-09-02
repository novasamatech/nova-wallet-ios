protocol TinderGovViewProtocol: ControllerBackedProtocol {}

protocol TinderGovPresenterProtocol: AnyObject {
    func setup()
    func actionBack()
}

protocol TinderGovInteractorInputProtocol: AnyObject {}

protocol TinderGovInteractorOutputProtocol: AnyObject {}

protocol TinderGovWireframeProtocol: AnyObject {
    func back(from view: ControllerBackedProtocol?)
}
