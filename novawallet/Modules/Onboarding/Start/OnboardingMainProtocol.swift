import Foundation
import Foundation_iOS

protocol OnboardingMainViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: OnboardingMainViewModel)
    func didReceiveConsent(accepted: Bool)
}

protocol OnboardingMainPresenterProtocol: AnyObject {
    func setup()
    func viewWillAppear()
    func updateLocalization()
    func toggleConsent()
    func activateSignup()
    func activateAccountRestore()
    func activateLegalDocument(url: URL)
}

protocol OnboardingMainWireframeProtocol: WebPresentable, ErrorPresentable, AlertPresentable, ActionsManagePresentable {
    func showSignup(from view: OnboardingMainViewProtocol?)
    func showAccountRestore(from view: OnboardingMainViewProtocol?)
    func showAccountSecretImport(from view: OnboardingMainViewProtocol?, source: SecretSource)
    func showWalletMigration(from view: OnboardingMainViewProtocol?, message: WalletMigrationMessage.Start)
}

protocol OnboardingMainInteractorInputProtocol: AnyObject {
    func setup()
    func acceptLegalDocuments()
}

protocol OnboardingMainInteractorOutputProtocol: AnyObject {
    func didSuggestSecretImport(source: SecretSource)
    func didSuggestWalletMigration(with message: WalletMigrationMessage.Start)
    func didReceiveError(_ error: Error)
}

protocol OnboardingMainViewFactoryProtocol {
    static func createViewForOnboarding() -> OnboardingMainViewProtocol?
}
