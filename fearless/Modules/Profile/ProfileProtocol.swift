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
    func didReceiveUserDataProvider(error: Error)
}

protocol ProfileWireframeProtocol: ErrorPresentable, AlertPresentable, WebPresentable, ModalAlertPresenting {
    func showAccountDetails(from view: ControllerBackedProtocol?)
    func showAccountSelection(from view: ControllerBackedProtocol?)
    func showNetworks(from view: ControllerBackedProtocol?)
    func showLanguageSelection(from view: ControllerBackedProtocol?)
    func showPincodeChange(from view: ControllerBackedProtocol?)
    func showAbout(from view: ControllerBackedProtocol?)
}

protocol ProfileViewFactoryProtocol: AnyObject {
    static func createView() -> ProfileViewProtocol?
}
