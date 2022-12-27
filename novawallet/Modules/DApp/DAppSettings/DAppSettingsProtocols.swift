protocol DAppSettingsViewProtocol: ControllerBackedProtocol {
    func update(title: String)
    func update(favoriteModel: TitleIconViewModel)
    func updateDesktopModel(_ titleModel: TitleIconViewModel, isOn: Bool)
}

protocol DAppSettingsPresenterProtocol: AnyObject {
    func setup()
    func changeDesktopMode(isOn: Bool)
    func presentFavorite()
}

protocol DAppSettingsDelegate: AnyObject {
    func addToFavorites(dAppIdentifier: String)
    func removeFromFavorites(dAppIdentifier: String)
    func desktopModeDidChanged(dAppIdentifier: String, isOn: Bool)
}
