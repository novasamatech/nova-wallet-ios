protocol LedgerInstructionsViewProtocol: ControllerBackedProtocol {
    func didReceive(migrationViewModel: LedgerMigrationBannerView.ViewModel)
}

protocol LedgerInstructionsPresenterProtocol: AnyObject {
    func setup()
    func showHint()
    func proceed()
}

protocol LedgerInstructionsWireframeProtocol: WebPresentable {
    func showOnContinue(from view: LedgerInstructionsViewProtocol?)
}
