import Foundation
import UIKit_iOS

final class PayShopSearchHeaderView: CollectionViewReusableContainerView<TitleCollectionHeaderView> {
    var titleLabel: UILabel { view.titleLabel }

    var searchButton: RoundedButton { view.button }

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

    private func applyLocalization() {
        titleLabel.text = R.string.localizable.shopMerchantsSearch(
            preferredLanguages: locale?.rLanguages
        )
    }

    private func configure() {
        view.apply(style: .titleWithButton)

        view.contentInsets = .zero

        titleLabel.apply(style: .title3Primary)
        view.iconWidth = 0
        view.spacing = 0

        searchButton.applyIconStyle()
        searchButton.contentInsets = .zero

        view.buttonWidth = 44

        searchButton.setIcon(R.image.iconSearchButton())
    }
}
