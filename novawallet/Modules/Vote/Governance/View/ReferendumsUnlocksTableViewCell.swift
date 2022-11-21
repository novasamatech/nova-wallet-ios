import UIKit

final class ReferendumsUnlocksView: GenericTitleValueView<
    GenericPairValueView<UILabel, BorderedIconLabelView>, IconDetailsView
> {
    var titleLabel: UILabel {
        titleView.fView
    }

    var locksLabel: UILabel {
        titleView.sView.iconDetailsView.detailsLabel
    }

    var unlocksLabel: UILabel {
        valueView.detailsLabel
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    func bind(viewModel: ReferendumsUnlocksViewModel, locale: Locale) {
        titleLabel.text = R.string.localizable.walletBalanceLocked(preferredLanguages: locale.rLanguages)
        locksLabel.text = viewModel.totalLock
        unlocksLabel.text = viewModel.hasUnlock ?
            R.string.localizable.commonUnlock(preferredLanguages: locale.rLanguages) : ""
    }

    private func configure() {
        titleView.setHorizontalAndSpacing(8.0)

        titleLabel.apply(style: .regularSubhedlinePrimary)

        locksLabel.apply(style: .footnoteSecondary)
        locksLabel.numberOfLines = 1

        unlocksLabel.apply(style: .unlockStyle)
        unlocksLabel.numberOfLines = 1

        titleView.sView.backgroundView.fillColor = R.color.colorWhite16()!
        titleView.sView.iconDetailsView.iconWidth = 12
        titleView.sView.iconDetailsView.spacing = 4
        titleView.sView.contentInsets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        titleView.sView.backgroundView.cornerRadius = 6
        titleView.sView.iconDetailsView.imageView.image = R.image.iconBrowserSecurity()?.tinted(
            with: R.color.colorWhite64()!
        )

        valueView.mode = .detailsIcon
        valueView.spacing = 4
        valueView.iconWidth = 24
        valueView.imageView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorWhite48()!)
    }
}

private extension UILabel.Style {
    static var unlockStyle: UILabel.Style {
        .init(textColor: R.color.colorGreen()!, font: .caption1)
    }
}

typealias ReferendumsUnlocksTableViewCell = BlurredTableViewCell<ReferendumsUnlocksView>

extension ReferendumsUnlocksTableViewCell {
    func applyStyle() {
        shouldApplyHighlighting = true
        contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        innerInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    }
}
