import Foundation
import Foundation_iOS

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
