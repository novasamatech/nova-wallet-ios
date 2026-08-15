import Foundation
import Foundation_iOS

struct LegalConsentViewModel {
    let title: String
    let subtitle: String
    let agreement: NSAttributedString
    let acceptTitle: String
    let consentAccepted: Bool
}

protocol LegalConsentViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: LegalConsentViewModel)
    func didReceiveConsent(accepted: Bool)
}

protocol LegalConsentPresenterProtocol: AnyObject {
    func setup()
    func updateLocalization()
    func toggleConsent()
    func activateLegalDocument(url: URL)
    func accept()
}

protocol LegalConsentInteractorInputProtocol: AnyObject {
    func acceptCurrentVersions()
}

protocol LegalConsentWireframeProtocol: WebPresentable {
    func complete(from view: LegalConsentViewProtocol?)
}
