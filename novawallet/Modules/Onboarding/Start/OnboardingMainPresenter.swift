import Foundation
import UIKit
import Foundation_iOS

final class OnboardingMainPresenter {
    weak var view: OnboardingMainViewProtocol?
    let wireframe: OnboardingMainWireframeProtocol
    let interactor: OnboardingMainInteractorInputProtocol

    let legalData: LegalData
    let consentService: ConsentServiceProtocol

    let locale: Locale

    init(
        interactor: OnboardingMainInteractorInputProtocol,
        wireframe: OnboardingMainWireframeProtocol,
        legalData: LegalData,
        consentService: ConsentServiceProtocol,
        locale: Locale
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.legalData = legalData
        self.consentService = consentService
        self.locale = locale
    }
}

extension OnboardingMainPresenter: OnboardingMainPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func activateTerms() {
        // Per Aurum mandate, the consent banner ToS link opens in the system
        // browser (not the in-app SFSafariViewController used elsewhere) so the
        // user reads the document outside of the app's wallet creation flow.
        UIApplication.shared.open(legalData.termsUrl)
    }

    func activatePrivacy() {
        // Per Aurum mandate, the consent banner Privacy Notice link opens in the
        // system browser (not the in-app SFSafariViewController used elsewhere).
        UIApplication.shared.open(legalData.privacyPolicyUrl)
    }

    func activateSignup() {
        // The view enforces that the consent checkbox is checked before this
        // method can be invoked. Persist the acceptance now so subsequent
        // wallet operations and the existing-user upgrade modal both observe
        // the recorded version.
        consentService.acceptCurrentConsent()
        wireframe.showSignup(from: view)
    }

    func activateAccountRestore() {
        consentService.acceptCurrentConsent()
        wireframe.showAccountRestore(from: view)
    }
}

extension OnboardingMainPresenter: OnboardingMainInteractorOutputProtocol {
    func didSuggestSecretImport(source: SecretSource) {
        wireframe.showAccountSecretImport(from: view, source: source)
    }

    func didSuggestWalletMigration(with message: WalletMigrationMessage.Start) {
        wireframe.showWalletMigration(from: view, message: message)
    }

    func didReceiveError(_ error: Error) {
        _ = wireframe.present(error: error, from: view, locale: locale)
    }
}
