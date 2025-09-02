import Foundation
import Foundation_iOS

final class OnboardingMainPresenter {
    weak var view: OnboardingMainViewProtocol?
    let wireframe: OnboardingMainWireframeProtocol
    let interactor: OnboardingMainInteractorInputProtocol

    let legalData: LegalData

    let locale: Locale

    init(
        interactor: OnboardingMainInteractorInputProtocol,
        wireframe: OnboardingMainWireframeProtocol,
        legalData: LegalData,
        locale: Locale
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.legalData = legalData
        self.locale = locale
    }
}

extension OnboardingMainPresenter: OnboardingMainPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func activateTerms() {
        if let view = view {
            wireframe.showWeb(
                url: legalData.termsUrl,
                from: view,
                style: .modal
            )
        }
    }

    func activatePrivacy() {
        if let view = view {
            wireframe.showWeb(
                url: legalData.privacyPolicyUrl,
                from: view,
                style: .modal
            )
        }
    }

    func activateSignup() {
        wireframe.showSignup(from: view)
    }

    func activateAccountRestore() {
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
