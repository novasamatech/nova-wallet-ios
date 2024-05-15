protocol BackupAttentionViewProtocol: ControllerBackedProtocol {
    func didReceive(_ viewModel: BackupAttentionViewLayout.Model)
}

protocol BackupAttentionPresenterProtocol: AnyObject {
    func setup()
}

protocol BackupAttentionWireframeProtocol: AnyObject {}
