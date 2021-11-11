import Foundation

protocol SettingsViewProtocol: ControllerBackedProtocol {
    func didLoad(userViewModel: ProfileUserViewModelProtocol)
    func didLoad(optionViewModels: [SettingsCellViewModel])
}

protocol SettingsPresenterProtocol: AnyObject {
    func setup()
    func activateAccountDetails()
    func activateOption(at index: UInt)
}

protocol SettingsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol SettingsInteractorOutputProtocol: AnyObject {
    func didReceive(userSettings: UserSettings)
    func didReceive(wallet: MetaAccountModel)
    func didReceiveUserDataProvider(error: Error)
}

protocol SettingsWireframeProtocol: ErrorPresentable, AlertPresentable, WebPresentable, ModalAlertPresenting {
    func showAccountDetails(for walletId: String, from view: ControllerBackedProtocol?)
    func showAccountSelection(from view: ControllerBackedProtocol?)
    func showConnectionSelection(from view: ControllerBackedProtocol?)
    func showLanguageSelection(from view: ControllerBackedProtocol?)
    func showPincodeChange(from view: ControllerBackedProtocol?)
    func showAbout(from view: ControllerBackedProtocol?)
}
