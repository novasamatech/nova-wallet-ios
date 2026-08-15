import Foundation
import Foundation_iOS

final class LegalConsentPresenter {
    weak var view: LegalConsentViewProtocol?

    let wireframe: LegalConsentWireframeProtocol
    let interactor: LegalConsentInteractorInputProtocol
    let legalData: LegalData
    let legalTextFactory: LegalConsentTextFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    private var consentAccepted: Bool = false

    init(
        interactor: LegalConsentInteractorInputProtocol,
        wireframe: LegalConsentWireframeProtocol,
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

private extension LegalConsentPresenter {
    func provideViewModel() {
        let locale = localizationManager.selectedLocale
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let viewModel = LegalConsentViewModel(
            title: strings.legalConsentTitle(),
            subtitle: strings.legalConsentSubtitle(),
            agreement: legalTextFactory.createAgreementText(
                for: locale,
                termsURL: legalData.termsUrl,
                privacyURL: legalData.privacyPolicyUrl
            ),
            acceptTitle: strings.legalConsentAccept(),
            consentAccepted: consentAccepted
        )

        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - LegalConsentPresenterProtocol

extension LegalConsentPresenter: LegalConsentPresenterProtocol {
    func setup() {
        provideViewModel()
    }

    func updateLocalization() {
        provideViewModel()
    }

    func toggleConsent() {
        consentAccepted = !consentAccepted

        view?.didReceiveConsent(accepted: consentAccepted)
    }

    func activateLegalDocument(url: URL) {
        guard let view else {
            return
        }

        wireframe.showWeb(url: url, from: view, style: .modal)
    }

    func accept() {
        guard consentAccepted else {
            return
        }

        interactor.acceptCurrentVersions()

        wireframe.complete(from: view)
    }
}
