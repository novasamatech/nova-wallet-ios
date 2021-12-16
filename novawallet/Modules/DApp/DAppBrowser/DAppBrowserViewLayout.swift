import UIKit
import WebKit

final class DAppBrowserViewLayout: UIView {
    let webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = WKUserContentController()

        let view = WKWebView(frame: .zero, configuration: configuration)
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(webView)

        webView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalTo(safeAreaLayoutGuide)
        }
    }
}
