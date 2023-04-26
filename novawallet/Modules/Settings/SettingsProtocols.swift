import Foundation
import UIKit.UIImage

protocol SettingsViewProtocol: ControllerBackedProtocol {
    func reload(sections: [(SettingsSection, [SettingsCellViewModel])])
    func didLoad(userViewModel: SettingsAccountViewModel)
}

protocol SettingsPresenterProtocol: AnyObject {
    var appNameText: String { get }
    func setup()
    func actionRow(_ row: SettingsRow)
    func handleWalletAction()
    func handleSwitchAction()
}

protocol SettingsViewModelFactoryProtocol: AnyObject {
    func createAccountViewModel(for wallet: MetaAccountModel) -> SettingsAccountViewModel

    func createSectionViewModels(
        language: Language?,
        currency: String?,
        isBiometricAuthOn: Bool?,
        isPinConfirmationOn: Bool,
        locale: Locale
    ) -> [(SettingsSection, [SettingsCellViewModel])]
}

protocol SettingsInteractorInputProtocol: AnyObject {
    func setup()
    func updateBiometricAuthSettings(isOn: Bool)
    func updatePinConfirmationSettings(isOn: Bool)
}

protocol SettingsInteractorOutputProtocol: AnyObject {
    func didReceive(wallet: MetaAccountModel)
    func didReceiveUserDataProvider(error: Error)
    func didReceive(currencyCode: String)
    func didReceive(biometrySettings: BiometrySettings)
    func didReceive(pinConfirmationEnabled: Bool)
    func didReceive(error: SettingsError)
}

protocol SettingsWireframeProtocol: ErrorPresentable, AlertPresentable, WebPresentable, ModalAlertPresenting,
    EmailPresentable, WalletSwitchPresentable, ApplicationSettingsPresentable, OperationAuthPresentable {
    func showAccountDetails(for walletId: String, from view: ControllerBackedProtocol?)
    func showAccountSelection(from view: ControllerBackedProtocol?)
    func showLanguageSelection(from view: ControllerBackedProtocol?)
    func showPincodeChange(from view: ControllerBackedProtocol?)
    func showCurrencies(from view: ControllerBackedProtocol?)
    func show(url: URL, from view: ControllerBackedProtocol?)
    func showPincode(completion: @escaping (Bool) -> Void)
}
