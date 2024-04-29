protocol WalletImportOptionsViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModel: WalletImportOptionViewModel)
}

protocol WalletImportOptionsPresenterProtocol: AnyObject {
    func setup()
}
