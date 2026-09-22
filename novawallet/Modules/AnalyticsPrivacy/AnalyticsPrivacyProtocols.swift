import Foundation

protocol AnalyticsPrivacyViewProtocol: ControllerBackedProtocol {
    func didReceive(isOn: Bool, canToggle: Bool)
}

protocol AnalyticsPrivacyPresenterProtocol: AnyObject {
    func setup()
    func setEnabled(_ enabled: Bool)
    func showPrivacyNotice()
}

protocol AnalyticsPrivacyInteractorInputProtocol: AnyObject {
    func setup()
    func setEnabled(_ enabled: Bool)
}

protocol AnalyticsPrivacyInteractorOutputProtocol: AnyObject {
    func didReceive(isEnabled: Bool, isAvailable: Bool)
}

protocol AnalyticsPrivacyWireframeProtocol: AnyObject {
    func showPrivacyNotice(from view: AnalyticsPrivacyViewProtocol?, url: URL)
}

protocol AnalyticsPrivacyPresentable: AnyObject {
    func showPrivacy(from view: ControllerBackedProtocol?)
}
