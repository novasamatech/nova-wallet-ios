protocol PayRootViewProtocol: ControllerBackedProtocol {
    func didReceive(pageProvider: PageViewProviding)
}

protocol PayRootPresenterProtocol: AnyObject {
    func setup()
}

protocol PayRootInteractorInputProtocol: AnyObject {
    func setup()
}

protocol PayRootInteractorOutputProtocol: AnyObject {
    func didCompleteSetup()
    func didChangeWallet()
}
