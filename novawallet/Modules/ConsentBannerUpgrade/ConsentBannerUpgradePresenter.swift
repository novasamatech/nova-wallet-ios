import Foundation
import UIKit

final class ConsentBannerUpgradePresenter {
    weak var view: ConsentBannerUpgradeViewProtocol?
    let wireframe: ConsentBannerUpgradeWireframeProtocol
    let consentService: ConsentServiceProtocol
    let onAcceptance: () -> Void

    init(
        wireframe: ConsentBannerUpgradeWireframeProtocol,
        consentService: ConsentServiceProtocol,
        onAcceptance: @escaping () -> Void
    ) {
        self.wireframe = wireframe
        self.consentService = consentService
        self.onAcceptance = onAcceptance
    }
}

extension ConsentBannerUpgradePresenter: ConsentBannerUpgradePresenterProtocol {
    func setup() {}

    func acceptConsent() {
        consentService.acceptCurrentConsent()

        // Defer onAcceptance until after the dismissal animation completes so
        // any subsequent OnLaunchAction modal isn't presented over a still-
        // animating dismiss transition.
        wireframe.close(view: view) { [weak self] in
            self?.onAcceptance()
        }
    }

    func activateTerms() {
        // Per Aurum mandate, the consent banner ToS link opens in the system
        // browser (not the in-app SFSafariViewController used elsewhere).
        UIApplication.shared.open(ConsentBannerConstants.termsOfServiceURL)
    }

    func activatePrivacy() {
        UIApplication.shared.open(ConsentBannerConstants.privacyNoticeURL)
    }
}
