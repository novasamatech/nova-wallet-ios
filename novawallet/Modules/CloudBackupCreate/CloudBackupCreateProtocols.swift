protocol CloudBackupCreateViewProtocol: ControllerBackedProtocol {}

protocol CloudBackupCreatePresenterProtocol: AnyObject {
    func setup()
}

protocol CloudBackupCreateInteractorInputProtocol: AnyObject {
    func createWallet(for password: String)
}

protocol CloudBackupCreateInteractorOutputProtocol: AnyObject {
    func didCreateWallet()
    func didReceive(error: CloudBackupCreateInteractorError)
}

protocol CloudBackupCreateWireframeProtocol: AlertPresentable, ErrorPresentable {}
