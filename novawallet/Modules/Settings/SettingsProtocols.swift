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

protocol SettingsInteractorInputProtocol: AnyObject {
    func setup()
    func connectWalletConnect(uri: String)
}

protocol SettingsInteractorOutputProtocol: AnyObject {
    func didReceive(wallet: MetaAccountModel)
    func didReceiveUserDataProvider(error: Error)
    func didReceive(currencyCode: String)
    func didReceiveWalletConnect(sessionsCount: Int)
}

protocol SettingsWireframeProtocol: ErrorPresentable, AlertPresentable, WebPresentable, ModalAlertPresenting,
    EmailPresentable, WalletSwitchPresentable, WalletConnectScanPresentable {
    func showAccountDetails(for walletId: String, from view: ControllerBackedProtocol?)
    func showAccountSelection(from view: ControllerBackedProtocol?)
    func showLanguageSelection(from view: ControllerBackedProtocol?)
    func showPincodeChange(from view: ControllerBackedProtocol?)
    func showCurrencies(from view: ControllerBackedProtocol?)
    func show(url: URL, from view: ControllerBackedProtocol?)
    func showWalletConnect(from view: ControllerBackedProtocol?)
}
