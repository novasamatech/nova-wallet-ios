import UIKit

final class PayShopLoadMoreView: GenericPairValueView<UIActivityIndicatorView, UILabel> {
    var activityIndicatorView: UIActivityIndicatorView {
        fView
    }

    var titleLabel: UILabel {
        sView
    }

    var locale: Locale? {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
        applyLocalization()
    }

    func startLoading() {
        activityIndicatorView.startAnimating()
    }

    func stopLoading() {
        activityIndicatorView.stopAnimating()
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable.shopMerchantsLoadingMore(preferredLanguages: locale?.rLanguages)
    }

    private func configure() {
        setVerticalAndSpacing(8)

        activityIndicatorView.style = .medium
        activityIndicatorView.hidesWhenStopped = false

        titleLabel.apply(style: .footnoteSecondary)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
    }
}

typealias PayShopLoadMoreCell = CollectionViewContainerCell<PayShopLoadMoreView>
