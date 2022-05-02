import SoraFoundation

protocol UsernameSetupViewProtocol: ControllerBackedProtocol {
    func setInput(viewModel: InputViewModelProtocol)
}

protocol UsernameSetupPresenterProtocol: AnyObject {
    func setup()
    func proceed()
}

protocol UsernameSetupInteractorInputProtocol: AnyObject {
    func setup()
}

protocol UsernameSetupInteractorOutputProtocol: AnyObject {}

protocol UsernameSetupWireframeProtocol: AlertPresentable {
    func proceed(from view: UsernameSetupViewProtocol?, walletName: String)
}

protocol UsernameSetupViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding() -> UsernameSetupViewProtocol?
    static func createViewForAdding() -> UsernameSetupViewProtocol?
    static func createViewForSwitch() -> UsernameSetupViewProtocol?
}
