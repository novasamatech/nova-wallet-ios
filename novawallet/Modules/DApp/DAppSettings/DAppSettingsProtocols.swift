protocol DAppSettingsViewProtocol: ControllerBackedProtocol {
    func update(title: String)
    func update(viewModels: [DAppGlobalSettingsViewModel])
}

protocol DAppSettingsPresenterProtocol: AnyObject {
    func setup()
    func changeDesktopMode(isOn: Bool)
    func presentFavorite()
}

protocol DAppSettingsDelegate: AnyObject {
    func addToFavorites(page: DAppBrowserPage)
    func removeFromFavorites(page: DAppBrowserPage)
    func desktopModeDidChanged(page: DAppBrowserPage, isOn: Bool)
}
