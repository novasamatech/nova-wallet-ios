protocol AppearanceSettingsViewProtocol: ControllerBackedProtocol {}

protocol AppearanceSettingsPresenterProtocol: AnyObject {
    func setup()
}

protocol AppearanceSettingsInteractorInputProtocol: AnyObject {}

protocol AppearanceSettingsInteractorOutputProtocol: AnyObject {}

protocol AppearanceSettingsWireframeProtocol: AnyObject {}
