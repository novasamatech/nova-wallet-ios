import RobinHood

protocol ManualBackupKeyListViewProtocol: ControllerBackedProtocol {
    func update(with viewModel: ManualBackupKeyListViewLayout.Model)
}

protocol ManualBackupKeyListPresenterProtocol: AnyObject {
    func setup()
}

protocol ManualBackupKeyListInteractorInputProtocol: AnyObject {
    func setup()
}

protocol ManualBackupKeyListInteractorOutputProtocol: AnyObject {
    func didReceive(_ chainsChange: [DataProviderChange<ChainModel>])
    func didReceive(_ error: Error)
}

protocol ManualBackupKeyListWireframeProtocol: AnyObject {}
