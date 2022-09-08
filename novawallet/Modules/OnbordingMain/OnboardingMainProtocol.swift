import Foundation

protocol OnboardingMainViewProtocol: ControllerBackedProtocol {}

protocol OnboardingMainPresenterProtocol: AnyObject {
    func setup()
    func activateSignup()
    func activateAccountRestore()
    func activateWatchOnlyCreate()
    func activateHardwareWalletCreate()
    func activateTerms()
    func activatePrivacy()
}

protocol OnboardingMainWireframeProtocol: WebPresentable, ErrorPresentable, AlertPresentable, ActionsManagePresentable {
    func showSignup(from view: OnboardingMainViewProtocol?)
    func showAccountRestore(from view: OnboardingMainViewProtocol?)
    func showKeystoreImport(from view: OnboardingMainViewProtocol?)
    func showWatchOnlyCreate(from view: OnboardingMainViewProtocol?)
    func showParitySignerWalletCreation(from view: OnboardingMainViewProtocol?)
    func showLedgerWalletCreation(from view: OnboardingMainViewProtocol?)
}

protocol OnboardingMainInteractorInputProtocol: AnyObject {
    func setup()
}

protocol OnboardingMainInteractorOutputProtocol: AnyObject {
    func didSuggestKeystoreImport()
}

protocol OnboardingMainViewFactoryProtocol {
    static func createViewForOnboarding() -> OnboardingMainViewProtocol?
    static func createViewForAdding() -> OnboardingMainViewProtocol?
    static func createViewForAccountSwitch() -> OnboardingMainViewProtocol?
}
