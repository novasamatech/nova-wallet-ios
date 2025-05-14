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
        titleLabel.apply(style: .semiboldCaps1Primary)
        view.iconWidth = 0
        view.spacing = 0

        searchButton.applyIconStyle()
        searchButton.setIcon(R.image.iconSearch())
        searchButton.contentInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)

        view.buttonWidth = 44
    }
}
