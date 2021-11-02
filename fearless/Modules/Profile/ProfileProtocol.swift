import Foundation

protocol ProfileViewProtocol: ControllerBackedProtocol {
    func didLoad(userViewModel: ProfileUserViewModelProtocol)
    func didLoad(optionViewModels: [ProfileOptionViewModelProtocol])
}

protocol ProfilePresenterProtocol: AnyObject {
    func setup()
    func activateAccountDetails()
    func activateOption(at index: UInt)
}

protocol ProfileInteractorInputProtocol: AnyObject {
    func setup()
}

protocol ProfileInteractorOutputProtocol: AnyObject {
    func didReceive(userSettings: UserSettings)
    func didReceive(wallet: MetaAccountModel)
    func didReceiveUserDataProvider(error: Error)
}

protocol ProfileWireframeProtocol: ErrorPresentable, AlertPresentable, WebPresentable, ModalAlertPresenting {
    func showAccountDetails(for walletId: String, from view: ProfileViewProtocol?)
    func showAccountSelection(from view: ProfileViewProtocol?)
    func showConnectionSelection(from view: ProfileViewProtocol?)
    func showLanguageSelection(from view: ProfileViewProtocol?)
    func showPincodeChange(from view: ProfileViewProtocol?)
    func showAbout(from view: ProfileViewProtocol?)
}

protocol ProfileViewFactoryProtocol: AnyObject {
    static func createView() -> ProfileViewProtocol?
}
