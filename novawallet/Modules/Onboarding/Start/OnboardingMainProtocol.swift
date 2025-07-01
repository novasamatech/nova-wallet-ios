import Foundation
import Foundation_iOS

protocol OnboardingMainViewProtocol: ControllerBackedProtocol {}

protocol OnboardingMainPresenterProtocol: AnyObject {
    func setup()
    func activateSignup()
    func activateAccountRestore()
    func activateTerms()
    func activatePrivacy()
}

protocol OnboardingMainWireframeProtocol: WebPresentable, ErrorPresentable, AlertPresentable, ActionsManagePresentable {
    func showSignup(from view: OnboardingMainViewProtocol?)
    func showAccountRestore(from view: OnboardingMainViewProtocol?)
    func showAccountSecretImport(from view: OnboardingMainViewProtocol?, source: SecretSource)
    func showWalletMigration(from view: OnboardingMainViewProtocol?, message: WalletMigrationMessage.Start)
}

protocol OnboardingMainInteractorInputProtocol: AnyObject {
    func setup()
}

protocol OnboardingMainInteractorOutputProtocol: AnyObject {
    func didSuggestSecretImport(source: SecretSource)
    func didSuggestWalletMigration(with message: WalletMigrationMessage.Start)
    func didReceiveError(_ error: Error)
}

protocol OnboardingMainViewFactoryProtocol {
    static func createViewForOnboarding() -> OnboardingMainViewProtocol?
}
