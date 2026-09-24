import Foundation

final class AnalyticsConsentScreenPresenter: AnalyticsConsentScreenPresenterProtocol {
    weak var view: AnalyticsConsentScreenViewProtocol?

    let interactor: AnalyticsConsentScreenInteractorInputProtocol
    let wireframe: AnalyticsConsentScreenWireframeProtocol
    let privacyPolicyURL: URL

    private var hasChosen = false

    init(
        interactor: AnalyticsConsentScreenInteractorInputProtocol,
        wireframe: AnalyticsConsentScreenWireframeProtocol,
        privacyPolicyURL: URL
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.privacyPolicyURL = privacyPolicyURL
    }

    func setup() {
        interactor.setup()
    }

    func agree() {
        complete(enabled: true)
    }

    func decline() {
        complete(enabled: false)
    }

    func showPrivacyNotice() {
        wireframe.showPrivacyNotice(from: view, url: privacyPolicyURL)
    }
}

extension AnalyticsConsentScreenPresenter: AnalyticsConsentScreenInteractorOutputProtocol {}

private extension AnalyticsConsentScreenPresenter {
    func complete(enabled: Bool) {
        guard !hasChosen else { return }

        hasChosen = true
        wireframe.complete(from: view, enabled: enabled)
    }
}
