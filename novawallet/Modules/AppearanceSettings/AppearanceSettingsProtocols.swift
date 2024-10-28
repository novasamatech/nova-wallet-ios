protocol AppearanceSettingsViewProtocol: ControllerBackedProtocol {
    func update(with initialViewModel: AppearanceSettingsIconsView.Model)
}

protocol AppearanceSettingsPresenterProtocol: AnyObject {
    func setup()
    func changeTokenIcons(
        with selectedOption: AppearanceSettingsIconsView.AppearanceOptions
    )
}

protocol AppearanceSettingsInteractorInputProtocol: AnyObject {
    func selectTokenIconsOption(_ option: AppearanceIconsOptions)
    func setup()
}

protocol AppearanceSettingsInteractorOutputProtocol: AnyObject {
    func didReceiveAppearance(iconsOption: AppearanceIconsOptions)
}

protocol AppearanceSettingsWireframeProtocol: AnyObject {}
