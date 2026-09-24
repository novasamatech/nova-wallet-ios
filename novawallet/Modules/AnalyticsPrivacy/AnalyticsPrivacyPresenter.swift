import Foundation

final class AnalyticsPrivacyPresenter {
    weak var view: AnalyticsPrivacyViewProtocol?

    let interactor: AnalyticsPrivacyInteractorInputProtocol
    let wireframe: AnalyticsPrivacyWireframeProtocol
    let privacyPolicyURL: URL

    init(
        interactor: AnalyticsPrivacyInteractorInputProtocol,
        wireframe: AnalyticsPrivacyWireframeProtocol,
        privacyPolicyURL: URL
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.privacyPolicyURL = privacyPolicyURL
    }
}

extension AnalyticsPrivacyPresenter: AnalyticsPrivacyPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func setEnabled(_ enabled: Bool) {
        interactor.setEnabled(enabled)
    }

    func showPrivacyNotice() {
        wireframe.showPrivacyNotice(from: view, url: privacyPolicyURL)
    }
}

extension AnalyticsPrivacyPresenter: AnalyticsPrivacyInteractorOutputProtocol {
    func didReceive(isEnabled: Bool, isAvailable: Bool) {
        view?.didReceive(isOn: isEnabled, canToggle: isEnabled || isAvailable)
    }
}
