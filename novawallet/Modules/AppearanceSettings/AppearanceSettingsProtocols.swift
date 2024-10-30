protocol AppearanceSettingsViewProtocol: ControllerBackedProtocol {
    func update(with initialViewModel: AppearanceSettingsIconsView.Model)
}

protocol AppearanceSettingsPresenterProtocol: AnyObject {
    func setup()
    func changeTokenIcons(
        with selectedOption: AppearanceSettingsIconsView.AppearanceOptions
    )
}

protocol AppearanceSettingsWireframeProtocol: AnyObject {}
