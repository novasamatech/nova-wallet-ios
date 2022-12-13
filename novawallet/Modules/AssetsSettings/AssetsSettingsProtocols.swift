protocol AssetsSettingsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: AssetsSettingsViewModel)
}

protocol AssetsSettingsPresenterProtocol: AnyObject {
    func setup()
    func setHideZeroBalances(value: Bool)
    func apply()
}

protocol AssetsSettingsInteractorInputProtocol: AnyObject {
    func setup()
    func save(hideZeroBalances: Bool)
}

protocol AssetsSettingsInteractorOutputProtocol: AnyObject {
    func didReceive(hideZeroBalances: Bool)
    func didSave()
}

protocol AssetsSettingsWireframeProtocol: AnyObject {
    func close(view: AssetsSettingsViewProtocol?)
}
