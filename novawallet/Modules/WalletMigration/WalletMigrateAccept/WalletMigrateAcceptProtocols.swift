protocol WalletMigrateAcceptViewProtocol: ControllerBackedProtocol {}

protocol WalletMigrateAcceptPresenterProtocol: AnyObject {
    func setup()
}

protocol WalletMigrateAcceptInteractorInputProtocol: AnyObject {
    func setup()
    func accept()
}

protocol WalletMigrateAcceptInteractorOutputProtocol: AnyObject {
    func didRequestMigration(from appScheme: String)
    func didCompleteMigration()
    func didFailMigration(with error: Error)
}

protocol WalletMigrateAcceptWireframeProtocol: AnyObject {}
