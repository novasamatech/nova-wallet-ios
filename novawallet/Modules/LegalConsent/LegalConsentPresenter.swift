import Foundation
import Foundation_iOS

final class LegalConsentPresenter {
    weak var view: LegalConsentViewProtocol?

    let wireframe: LegalConsentWireframeProtocol
    let interactor: LegalConsentInteractorInputProtocol
    let legalData: LegalData
    let localizationManager: LocalizationManagerProtocol

    private var consentAccepted: Bool = false

    init(
        interactor: LegalConsentInteractorInputProtocol,
        wireframe: LegalConsentWireframeProtocol,
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

private extension LegalConsentPresenter {
    func provideViewModel() {
        let locale = localizationManager.selectedLocale
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let viewModel = LegalConsentViewModel(
            title: strings.legalConsentTitle(),
            subtitle: strings.legalConsentSubtitle(),
            agreement: LegalConsentTextFactory.createAgreementText(for: locale),
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

    func activateLegalDocument(_ type: LegalDocumentType) {
        guard let view else {
            return
        }

        let url = switch type {
        case .termsOfService: legalData.termsUrl
        case .privacyNotice: legalData.privacyPolicyUrl
        }

        // The browser opens on top of the sheet: the sheet stays presented, still un-dismissible,
        // and the checkbox state survives.
        wireframe.showWeb(url: url, from: view, style: .modal)
    }

    func accept() {
        // Defensive re-check on top of the disabled button: accessibility actions can bypass it.
        guard consentAccepted else {
            return
        }

        interactor.acceptCurrentVersions()

        wireframe.complete(from: view)
    }
}
