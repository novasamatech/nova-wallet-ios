import Foundation

protocol AnalyticsConsentScreenViewProtocol: ControllerBackedProtocol {}

protocol AnalyticsConsentScreenPresenterProtocol: AnyObject {
    func setup()
    func agree()
    func decline()
    func showPrivacyNotice()
}

protocol AnalyticsConsentScreenInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AnalyticsConsentScreenInteractorOutputProtocol: AnyObject {}

protocol AnalyticsConsentScreenWireframeProtocol: WebPresentable {
    func complete(from view: AnalyticsConsentScreenViewProtocol?, enabled: Bool)
    func showPrivacyNotice(from view: AnalyticsConsentScreenViewProtocol?, url: URL)
}
