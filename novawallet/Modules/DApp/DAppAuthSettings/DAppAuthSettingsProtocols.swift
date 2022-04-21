import RobinHood
import CommonWallet

protocol DAppAuthSettingsViewProtocol: ControllerBackedProtocol {
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAuthorized(viewModels: [DAppAuthSettingsViewModel])
}

protocol DAppAuthSettingsPresenterProtocol: AnyObject {
    func setup()
    func remove(viewModel: DAppAuthSettingsViewModel)
}

protocol DAppAuthSettingsInteractorInputProtocol: AnyObject {
    func setup()
    func remove(auth: DAppSettings)
}

protocol DAppAuthSettingsInteractorOutputProtocol: AnyObject {
    func didReceiveDAppList(_ list: DAppList?)
    func didReceiveAuthorizationSettings(changes: [DataProviderChange<DAppSettings>])
    func didReceive(error: Error)
}

protocol DAppAuthSettingsWireframeProtocol: ErrorPresentable, DAppAlertPresentable {}
