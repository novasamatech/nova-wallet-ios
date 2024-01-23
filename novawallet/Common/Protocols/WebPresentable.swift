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
    var supportedSafariScheme: [String] {
        ["https", "http"]
    }

    func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle) {
        let defaultController = UIApplication.shared.delegate?.window??.rootViewController
        guard let viewController = view.controller.presentingViewController ?? defaultController else {
            return
        }

        showWeb(url: url, from: viewController, style: style)
    }

    func showWeb(url: URL, from viewController: UIViewController, style: WebPresentableStyle) {
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
