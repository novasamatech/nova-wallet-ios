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
}

protocol SettingsViewModelFactoryProtocol: AnyObject {
    func createAccountViewModel(for wallet: MetaAccountModel) -> SettingsAccountViewModel

    func createSectionViewModels(
        language: Language?,
        locale: Locale
    ) -> [(SettingsSection, [SettingsCellViewModel])]
}

protocol SettingsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol SettingsInteractorOutputProtocol: AnyObject {
    func didReceive(wallet: MetaAccountModel)
    func didReceiveUserDataProvider(error: Error)
}

protocol SettingsWireframeProtocol: ErrorPresentable, AlertPresentable, WebPresentable, ModalAlertPresenting,
    EmailPresentable {
    func showAccountDetails(for walletId: String, from view: ControllerBackedProtocol?)
    func showAccountSelection(from view: ControllerBackedProtocol?)
    func showLanguageSelection(from view: ControllerBackedProtocol?)
    func showPincodeChange(from view: ControllerBackedProtocol?)
}
