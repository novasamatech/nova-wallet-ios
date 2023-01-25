protocol InAppUpdatesViewProtocol: ControllerBackedProtocol {}

protocol InAppUpdatesPresenterProtocol: AnyObject {
    func setup()
}

protocol InAppUpdatesInteractorInputProtocol: AnyObject {
    func setup()
    func loadChangeLogs()
}

protocol InAppUpdatesInteractorOutputProtocol: AnyObject {
    func didReceive(error: InAppUpdatesInteractorError)
    func didReceiveLastVersion(changelog: ChangeLog)
    func didReceiveAllVersions(changelogs: [ChangeLog])
}

protocol InAppUpdatesWireframeProtocol: AnyObject {}
