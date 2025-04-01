import UIKit
import WebKit

final class PayCardViewLayout: UIView {
    let webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = WKUserContentController()
        configuration.allowsInlineMediaPlayback = true

        let preferences = WKWebpagePreferences()
        preferences.preferredContentMode = .mobile
        configuration.defaultWebpagePreferences = preferences

        let view = WKWebView(frame: .zero, configuration: configuration)

        view.scrollView.contentInsetAdjustmentBehavior = .always
        view.scrollView.backgroundColor = R.color.colorSecondaryScreenBackground()

        if #available(iOS 16.4, *) {
            view.isInspectable = true
        }

        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(webView)
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
