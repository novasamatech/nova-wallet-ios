import Foundation

final class AnalyticsConsentScreenWireframe: AnalyticsConsentScreenWireframeProtocol {
    private let onEnable: () -> Void
    private let onDecline: () -> Void

    init(onEnable: @escaping () -> Void, onDecline: @escaping () -> Void) {
        self.onEnable = onEnable
        self.onDecline = onDecline
    }

    func complete(from view: AnalyticsConsentScreenViewProtocol?, enabled: Bool) {
        let completion = enabled ? onEnable : onDecline
        view?.controller.dismiss(animated: true, completion: completion)
    }

    func showPrivacyNotice(from view: AnalyticsConsentScreenViewProtocol?, url: URL) {
        guard let view else { return }

        showWeb(url: url, from: view, style: .modal)
    }
}
