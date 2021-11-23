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

protocol UsernameSetupWireframeProtocol: AlertPresentable, NetworkTypeSelectionPresentable {
    func proceed(from view: UsernameSetupViewProtocol?, model: UsernameSetupModel)
}

protocol UsernameSetupViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding() -> UsernameSetupViewProtocol?
    static func createViewForAdding() -> UsernameSetupViewProtocol?
    // TODO: Remove method completely
//    static func createViewForSwitch() -> UsernameSetupViewProtocol?
}
