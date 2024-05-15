protocol BackupAttentionViewProtocol: ControllerBackedProtocol {
    func didReceive(_ viewModel: BackupAttentionViewLayout.Model)
}

protocol BackupAttentionPresenterProtocol: AnyObject {
    func setup()
}

protocol BackupAttentionInteractorInputProtocol: AnyObject {}

protocol BackupAttentionInteractorOutputProtocol: AnyObject {}

protocol BackupAttentionWireframeProtocol: AnyObject {}
