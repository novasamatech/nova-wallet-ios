import UIKit

final class StakingUnbondingItemView: GenericTitleValueView<UILabel, IconDetailsView> {
    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
    }

    private func configureStyle() {
        titleView.textColor = R.color.colorWhite()!
        titleView.font = .regularSubheadline

        valueView.mode = .detailsIcon
        valueView.detailsLabel.numberOfLines = 1
    }

    func bind(title: String, timeLeft: String?, locale: Locale) {
        titleView.text = title

        if let timeLeft = timeLeft {
            valueView.detailsLabel.textColor = R.color.colorTransparentText()
            valueView.detailsLabel.text = timeLeft

            valueView.spacing = 4.0
            valueView.iconWidth = 16.0

            let icon = R.image.iconPending()?.tinted(with: R.color.colorWhite48()!)
            valueView.imageView.image = icon
        } else {
            valueView.detailsLabel.textColor = R.color.colorGreen()
            valueView.detailsLabel.text = R.string.localizable.walletBalanceRedeemable(
                preferredLanguages: locale.rLanguages
            )

            valueView.spacing = 0.0
            valueView.iconWidth = 0.0
            valueView.imageView.image = nil
        }
    }
}
