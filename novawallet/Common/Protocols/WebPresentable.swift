import Foundation
import UIKit
import SafariServices

enum WebPresentableStyle {
    case automatic
    case modal
}

protocol WebPresentable: AnyObject {
    func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)
}

extension WebPresentable {
    func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle) {
        showWeb(url: url, from: view.controller, style: style)
    }

    func showWeb(url: URL, from viewController: UIViewController, style: WebPresentableStyle) {
        let supportedSafariScheme = ["https", "http"]
        guard let scheme = url.scheme, supportedSafariScheme.contains(scheme) else {
            return
        }

        let webController = WebViewFactory.createWebViewController(for: url, style: style)
        viewController.present(webController, animated: true, completion: nil)
    }
}

enum WebViewFactory {
    static func createWebViewController(for url: URL, style: WebPresentableStyle) -> UIViewController {
        let webController = SFSafariViewController(url: url)
        webController.preferredControlTintColor = R.color.colorIconPrimary()
        webController.preferredBarTintColor = R.color.colorDAppBlurNavigationBackground()

        switch style {
        case .modal:
            webController.modalPresentationStyle = .overFullScreen
        default:
            break
        }

        return webController
    }
}
