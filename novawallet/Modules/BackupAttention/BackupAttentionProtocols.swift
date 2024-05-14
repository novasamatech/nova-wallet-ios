protocol BackupAttentionViewProtocol: ControllerBackedProtocol {}

protocol BackupAttentionPresenterProtocol: AnyObject {
    func setup()
}

protocol BackupAttentionInteractorInputProtocol: AnyObject {}

protocol BackupAttentionInteractorOutputProtocol: AnyObject {}

protocol BackupAttentionWireframeProtocol: AnyObject {}