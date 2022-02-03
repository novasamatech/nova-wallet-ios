protocol AssetsManageViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: AssetsManageViewModel)
}

protocol AssetsManagePresenterProtocol: AnyObject {
    func setup()
    func setHideZeroBalances(value: Bool)
    func apply()
}

protocol AssetsManageInteractorInputProtocol: AnyObject {
    func setup()
    func save(hideZeroBalances: Bool)
}

protocol AssetsManageInteractorOutputProtocol: AnyObject {
    func didReceive(hideZeroBalances: Bool)
    func didSave()
}

protocol AssetsManageWireframeProtocol: AnyObject {
    func close(view: AssetsManageViewProtocol?)
}
