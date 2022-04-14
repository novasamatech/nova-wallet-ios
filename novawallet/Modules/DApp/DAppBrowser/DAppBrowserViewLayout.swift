import UIKit
import WebKit
import SoraUI

final class DAppBrowserViewLayout: UIView {
    private enum Constants {
        static let toolbarHeight: CGFloat = 44.0
    }

    let urlBar = DAppURLBarView()

    var securityImageView: UIImageView { urlBar.controlContentView.imageView }
    var urlLabel: UILabel { urlBar.controlContentView.detailsLabel }

    let closeBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: R.image.iconClose()!, style: .plain, target: nil, action: nil)
        item.tintColor = R.color.colorWhite()
        return item
    }()

    let refreshBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: R.image.iconRefresh()!, style: .plain, target: nil, action: nil)
        item.tintColor = R.color.colorWhite()
        return item
    }()

    let goBackBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: R.image.iconBrowserBack()!, style: .plain, target: nil, action: nil)
        item.tintColor = R.color.colorWhite()
        return item
    }()

    let goForwardBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: R.image.iconBrowserForward()!, style: .plain, target: nil, action: nil)
        item.tintColor = R.color.colorWhite()
        return item
    }()

    let favoriteBarButton: UIBarButtonItem = {
        let item = UIBarButtonItem(image: R.image.iconFavToolbar()!, style: .plain, target: nil, action: nil)
        return item
    }()

    let toolbarBackgroundView: TriangularedBlurView = {
        let view = TriangularedBlurView()
        view.sideLength = 0.0
        return view
    }()

    let toolBar: UIToolbar = {
        let view = UIToolbar()
        view.setBackgroundImage(UIImage(), forToolbarPosition: .bottom, barMetrics: .default)
        view.setShadowImage(UIImage(), forToolbarPosition: .bottom)

        return view
    }()

    let webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = WKUserContentController()

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.scrollView.contentInsetAdjustmentBehavior = .always

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

        addSubview(toolbarBackgroundView)
        toolbarBackgroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-Constants.toolbarHeight)
        }

        addSubview(toolBar)
        toolBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(Constants.toolbarHeight)
        }

        webView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.equalTo(toolBar.snp.top)
        }

        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        toolBar.items = [
            goBackBarItem,
            flexibleSpace,
            goForwardBarItem,
            flexibleSpace,
            refreshBarItem,
            flexibleSpace,
            favoriteBarButton
        ]
    }
}
