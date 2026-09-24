import Foundation
import NovaAnalytics

final class AnalyticsPrivacyInteractor {
    weak var presenter: AnalyticsPrivacyInteractorOutputProtocol?

    let consentManager: AnalyticsConsentManagerProtocol

    init(consentManager: AnalyticsConsentManagerProtocol) {
        self.consentManager = consentManager
    }

    deinit {
        consentManager.removeObserver(by: self)
        consentManager.removeAvailabilityObserver(by: self)
    }
}

extension AnalyticsPrivacyInteractor: AnalyticsPrivacyInteractorInputProtocol {
    func setup() {
        consentManager.addObserver(with: self, queue: .main) { [weak self] _, _ in
            self?.provideState()
        }

        consentManager.addAvailabilityObserver(with: self, queue: .main) { [weak self] _ in
            self?.provideState()
        }

        provideState()
    }

    func setEnabled(_ enabled: Bool) {
        if !enabled || consentManager.isAvailable {
            consentManager.setEnabled(enabled)
        }

        provideState()
    }
}

private extension AnalyticsPrivacyInteractor {
    func provideState() {
        presenter?.didReceive(
            isEnabled: consentManager.isEnabled,
            isAvailable: consentManager.isAvailable
        )
    }
}
