import Foundation
import Foundation_iOS

final class OnboardingMainPresenter {
    weak var view: OnboardingMainViewProtocol?
    let wireframe: OnboardingMainWireframeProtocol
    let interactor: OnboardingMainInteractorInputProtocol

    let legalData: LegalData
    let localizationManager: LocalizationManagerProtocol

    private var consentAccepted: Bool = false

    init(
        interactor: OnboardingMainInteractorInputProtocol,
        wireframe: OnboardingMainWireframeProtocol,
        legalData: LegalData,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.legalData = legalData
        self.localizationManager = localizationManager
    }
}

// MARK: - Private

private extension OnboardingMainPresenter {
    func provideViewModel() {
        let viewModel = OnboardingMainViewModel(
            agreement: LegalConsentTextFactory.createAgreementText(
                for: localizationManager.selectedLocale
            ),
            consentAccepted: consentAccepted
        )

        view?.didReceive(viewModel: viewModel)
    }

    func proceed(_ navigationClosure: (OnboardingMainViewProtocol?) -> Void) {
        guard consentAccepted else {
            return
        }

        // Proceeding from this screen records acceptance of the current documents, and does it
        // before navigating so the write is durable.
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

    /// The checkbox is not persisted: leaving and returning resets it. The next screen is pushed
    /// over this one, so the presenter survives the round trip and must reset explicitly. Returning
    /// from the in-app browser does not reset it because the browser is presented over full screen
    /// and does not re-run `viewWillAppear`.
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

    func activateLegalDocument(_ type: LegalDocumentType) {
        guard let view else {
            return
        }

        let url = switch type {
        case .termsOfService: legalData.termsUrl
        case .privacyNotice: legalData.privacyPolicyUrl
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
