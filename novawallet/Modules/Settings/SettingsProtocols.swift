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
    func createAccountViewModel(for wallet: MetaAccountModel, hasWalletNotification: Bool) -> SettingsAccountViewModel

    func createSectionViewModels(
        language: Language?,
        currency: String?,
        parameters: SettingsParameters,
        locale: Locale
    ) -> [(SettingsSection, [SettingsCellViewModel])]
}

protocol SettingsInteractorInputProtocol: AnyObject {
    func setup()
    func updateBiometricAuthSettings(isOn: Bool)
    func updatePinConfirmationSettings(isOn: Bool)
    func connectWalletConnect(uri: String)
}

protocol SettingsInteractorOutputProtocol: AnyObject {
    func didReceive(wallet: MetaAccountModel)
    func didReceiveUserDataProvider(error: Error)
    func didReceive(currencyCode: String)
    func didReceiveWalletConnect(sessionsCount: Int)
    func didReceive(biometrySettings: BiometrySettings)
    func didReceive(pinConfirmationEnabled: Bool)
    func didReceive(error: SettingsError)
    func didReceiveWalletsState(hasUpdates: Bool)
    func didReceive(pushNotificationsStatus: PushNotificationsStatus)
}

protocol SettingsWireframeProtocol:
    AuthorizationPresentable,
    ErrorPresentable,
    AlertPresentable,
    WebPresentable,
    ModalAlertPresenting,
    EmailPresentable,
    WalletSwitchPresentable,
    ApplicationSettingsPresentable,
    OperationAuthPresentable,
    WalletConnectScanPresentable,
    WalletConnectErrorPresentable,
    RampPresentable {
    func showAccountDetails(for walletId: String, from view: ControllerBackedProtocol?)
    func showAccountSelection(from view: ControllerBackedProtocol?)
    func showLanguageSelection(from view: ControllerBackedProtocol?)
    func showPincodeChange(from view: ControllerBackedProtocol?)
    func showCurrencies(from view: ControllerBackedProtocol?)
    func show(url: URL, from view: ControllerBackedProtocol?)
    func showAuthorization(completion: @escaping (Bool) -> Void)
    func showWalletConnect(from view: ControllerBackedProtocol?)
    func showPincodeAuthorization(completion: @escaping (Bool) -> Void)
    func showManageNotifications(from view: ControllerBackedProtocol?)
    func showBackup(from view: ControllerBackedProtocol?)
    func showNetworks(from view: ControllerBackedProtocol?)
    func showAppearance(from view: ControllerBackedProtocol?)
}
