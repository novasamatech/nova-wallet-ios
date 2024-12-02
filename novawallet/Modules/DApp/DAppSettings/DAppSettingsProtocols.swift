protocol DAppSettingsViewProtocol: ControllerBackedProtocol {
    func update(title: String)
    func update(viewModels: [DAppGlobalSettingsViewModel])
}

protocol DAppSettingsPresenterProtocol: AnyObject {
    func setup()
    func changeDesktopMode(isOn: Bool)
}

protocol DAppSettingsDelegate: AnyObject {
    func desktopModeDidChanged(page: DAppBrowserPage, isOn: Bool)
}
