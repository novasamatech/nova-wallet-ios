protocol InAppUpdatesViewProtocol: ControllerBackedProtocol {}

protocol InAppUpdatesPresenterProtocol: AnyObject {
    func setup()
}

protocol InAppUpdatesInteractorInputProtocol: AnyObject {
    func setup()
    func loadAllChangeLogs()
    func loadLastVersionChangeLog()
}

protocol InAppUpdatesInteractorOutputProtocol: AnyObject {}

protocol InAppUpdatesWireframeProtocol: AnyObject {}
