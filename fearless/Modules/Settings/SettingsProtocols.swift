import Foundation

protocol SettingsViewProtocol: ControllerBackedProtocol {
    func reload(sections: [(SettingsSection, [SettingsCellViewModel])])
}

protocol SettingsPresenterProtocol: AnyObject {
    var appNameText: String { get }
    func setup()
    func actionRow(_ row: SettingsRow)
}

protocol SettingsViewModelFactoryProtocol: AnyObject {
    func createSectionViewModels(
        language: Language?,
        locale: Locale
    ) -> [(SettingsSection, [SettingsCellViewModel])]
}

protocol SettingsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol SettingsInteractorOutputProtocol: AnyObject {
    func didReceive(userSettings: UserSettings)
    func didReceiveUserDataProvider(error: Error)
}

protocol SettingsWireframeProtocol: ErrorPresentable, AlertPresentable, WebPresentable, ModalAlertPresenting {
    func showAccountDetails(for walletId: String, from view: ControllerBackedProtocol?)
    func showAccountSelection(from view: ControllerBackedProtocol?)
    func showConnectionSelection(from view: ControllerBackedProtocol?)
    func showLanguageSelection(from view: ControllerBackedProtocol?)
    func showPincodeChange(from view: ControllerBackedProtocol?)
}
