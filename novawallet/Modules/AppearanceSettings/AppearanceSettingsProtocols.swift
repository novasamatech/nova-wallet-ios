protocol AppearanceSettingsViewProtocol: ControllerBackedProtocol {}

protocol AppearanceSettingsPresenterProtocol: AnyObject {
    func setup()
    func changeTokenIcons(
        with selectedOption: AppearanceSettingsIconsView.AppearanceIconsOptions
    )
}

protocol AppearanceSettingsInteractorInputProtocol: AnyObject {}

protocol AppearanceSettingsInteractorOutputProtocol: AnyObject {}

protocol AppearanceSettingsWireframeProtocol: AnyObject {}
