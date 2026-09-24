import Foundation

final class AnalyticsPrivacyWireframe: AnalyticsPrivacyWireframeProtocol, WebPresentable {
    func showPrivacyNotice(from view: AnalyticsPrivacyViewProtocol?, url: URL) {
        guard let view else {
            return
        }

        showWeb(url: url, from: view, style: .automatic)
    }
}
