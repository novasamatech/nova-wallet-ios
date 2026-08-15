import Foundation
import Foundation_iOS

final class OnboardingMainPresenter {
    weak var view: OnboardingMainViewProtocol?
    let wireframe: OnboardingMainWireframeProtocol
    let interactor: OnboardingMainInteractorInputProtocol

    let legalData: LegalData
    let legalTextFactory: LegalConsentTextFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    private var consentAccepted: Bool = false

    init(
        interactor: OnboardingMainInteractorInputProtocol,
        wireframe: OnboardingMainWireframeProtocol,
        legalData: LegalData,
        legalTextFactory: LegalConsentTextFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.legalData = legalData
        self.legalTextFactory = legalTextFactory
        self.localizationManager = localizationManager
    }
}

// MARK: - Private

private extension OnboardingMainPresenter {
    func provideViewModel() {
        let viewModel = OnboardingMainViewModel(
            agreement: legalTextFactory.createAgreementText(
                for: localizationManager.selectedLocale,
                termsURL: legalData.termsUrl,
                privacyURL: legalData.privacyPolicyUrl
            ),
            consentAccepted: consentAccepted
        )

        view?.didReceive(viewModel: viewModel)
    }

    func proceed(_ navigationClosure: (OnboardingMainViewProtocol?) -> Void) {
        guard consentAccepted else {
            return
        }

        interactor.acceptLegalDocuments()

        navigationClosure(view)
    }
}

// MARK: - OnboardingMainPresenterProtocol

extension OnboardingMainPresenter: OnboardingMainPresenterProtocol {
    func setup() {
        provideViewModel()

        interactor.setup()
    }

    func viewWillAppear() {
        guard consentAccepted else {
            return
        }

        consentAccepted = false

        view?.didReceiveConsent(accepted: false)
    }

    func updateLocalization() {
        provideViewModel()
    }

    func toggleConsent() {
        consentAccepted = !consentAccepted

        view?.didReceiveConsent(accepted: consentAccepted)
    }

    func activateSignup() {
        proceed { [weak self] view in
            self?.wireframe.showSignup(from: view)
        }
    }

    func activateAccountRestore() {
        proceed { [weak self] view in
            self?.wireframe.showAccountRestore(from: view)
        }
    }

    func activateLegalDocument(url: URL) {
        guard let view else {
            return
        }

        wireframe.showWeb(url: url, from: view, style: .modal)
    }
}

// MARK: - OnboardingMainInteractorOutputProtocol

extension OnboardingMainPresenter: OnboardingMainInteractorOutputProtocol {
    func didSuggestSecretImport(source: SecretSource) {
        wireframe.showAccountSecretImport(from: view, source: source)
    }

    func didSuggestWalletMigration(with message: WalletMigrationMessage.Start) {
        wireframe.showWalletMigration(from: view, message: message)
    }

    func didReceiveError(_ error: Error) {
        _ = wireframe.present(
            error: error,
            from: view,
            locale: localizationManager.selectedLocale
        )
    }
}
