import UIKit
import WebKit
import UIKit_iOS

final class DAppBrowserViewLayout: UIView {
    var securityImageView: UIImageView { urlBar.controlContentView.imageView }
    var urlLabel: UILabel { urlBar.controlContentView.detailsLabel }

    // MARK: Top bar controls

    let urlBar = DAppURLBarView()

    let minimizeBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: R.image.iconSmallArrowDown()!,
            style: .plain,
            target: nil,
            action: nil
        )
        item.tintColor = R.color.colorIconPrimary()!
        return item
    }()

    let refreshBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: R.image.iconRefresh()!,
            style: .plain,
            target: nil,
            action: nil
        )
        item.tintColor = R.color.colorIconPrimary()
        return item
    }()

    // MARK: Bottom bar controls

    let favoriteBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: R.image.iconFavToolbar()!,
            style: .plain,
            target: nil,
            action: nil
        )

        item.tintColor = R.color.colorIconPrimary()

        return item
    }()

    let goBackBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: R.image.iconBrowserBack()!,
            style: .plain,
            target: nil,
            action: nil
        )
        item.tintColor = R.color.colorIconPrimary()
        return item
    }()

    let goForwardBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: R.image.iconBrowserForward()!,
            style: .plain,
            target: nil,
            action: nil
        )
        item.tintColor = R.color.colorIconPrimary()
        return item
    }()

    let tabsButton: RoundedButton = .create { view in
        view.imageWithTitleView?.titleFont = .semiBoldCaption1
        view.imageWithTitleView?.spacingBetweenLabelAndIcon = Constants.tabsButtonContentSpacing
        view.roundedBackgroundView?.applyStrokedBackgroundStyle()
        view.roundedBackgroundView?.cornerRadius = Constants.tabsButtonCornerRadius
        view.roundedBackgroundView?.strokeWidth = Constants.tabsButtonStrokeWidth
        view.roundedBackgroundView?.strokeColor = R.color.colorTextPrimary()!

        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    lazy var tabsButtonItem: UIBarButtonItem = {
        let containerView = UIView()
        containerView.addSubview(tabsButton)

        containerView.snp.makeConstraints { make in
            make.width.height.equalTo(Constants.tabsButtonSize).priority(.required)
        }

        tabsButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(Constants.tabsButtonSize).priority(.required)
        }

        let item = UIBarButtonItem(customView: containerView)
        return item
    }()

    let settingsBarButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: R.image.iconMore(),
            style: .plain,
            target: nil,
            action: nil
        )
        item.tintColor = R.color.colorIconPrimary()
        item.isEnabled = false
        return item
    }()

    let toolbarBackgroundView: BlurBackgroundView = {
        let view = BlurBackgroundView()
        view.sideLength = 0.0
        view.borderType = []
        return view
    }()

    let toolBar: UIToolbar = {
        let view = UIToolbar()
        view.setBackgroundImage(UIImage(), forToolbarPosition: .bottom, barMetrics: .default)
        view.setShadowImage(UIImage(), forToolbarPosition: .bottom)

        return view
    }()

    let webViewContainer = UIView()

    var webView: WKWebView?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension DAppBrowserViewLayout {
    func setupLayout() {
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

        addSubview(webViewContainer)
        webViewContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.equalTo(toolBar.snp.top)
        }

        let flexibleSpace = UIBarButtonItem(
            barButtonSystemItem: .flexibleSpace,
            target: nil,
            action: nil
        )

        toolBar.items = [
            goBackBarItem,
            flexibleSpace,
            goForwardBarItem,
            flexibleSpace,
            tabsButtonItem,
            flexibleSpace,
            favoriteBarItem,
            flexibleSpace,
            settingsBarButton
        ]
    }
}

// MARK: Internal

extension DAppBrowserViewLayout {
    func setIsToolbarHidden(_ isHidden: Bool) {
        toolbarBackgroundView.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()

            if isHidden {
                make.bottom.equalToSuperview().offset(Constants.toolbarHeight)
                make.top.equalTo(self.snp.bottom)
            } else {
                make.bottom.equalToSuperview()
                make.top.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-Constants.toolbarHeight)
            }
        }

        toolBar.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.toolbarHeight)

            if isHidden {
                make.bottom.equalToSuperview().offset(Constants.toolbarHeight)
            } else {
                make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
            }
        }

        layoutIfNeeded()
    }

    func setFavorite(_ favorite: Bool) {
        if favorite {
            favoriteBarItem.image = R.image.iconFavToolbarSel()
            favoriteBarItem.tintColor = R.color.colorIconFavorite()
        } else {
            favoriteBarItem.image = R.image.iconFavToolbar()
            favoriteBarItem.tintColor = R.color.colorIconPrimary()
        }
    }

    func setURLSecure(_ secure: Bool) {
        if secure {
            securityImageView.image = R.image.iconBrowserSecurity()?
                .tinted(with: R.color.colorIconPositive()!)
            urlLabel.textColor = R.color.colorTextPositive()
        } else {
            securityImageView.image = nil
            urlLabel.textColor = R.color.colorTextPrimary()
        }
    }

    func setWebView(_ webView: WKWebView) {
        self.webView?.removeFromSuperview()
        self.webView = webView

        webViewContainer.addSubview(webView)

        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

// MARK: Constants

private extension DAppBrowserViewLayout {
    enum Constants {
        static let toolbarHeight: CGFloat = 44.0
        static let tabsButtonSize: CGFloat = 24.0
        static let tabsButtonContentSpacing: CGFloat = 0.0
        static let tabsButtonCornerRadius: CGFloat = 6.0
        static let tabsButtonStrokeWidth: CGFloat = 1.2
    }
}
