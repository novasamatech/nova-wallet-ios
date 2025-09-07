import UIKit

final class StakingDashboardMoreOptionsCell: BlurredCollectionViewCell<
    GenericTitleValueView<UILabel, UIImageView>
> {
    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    private func configure() {
        view.view.titleView.apply(style: .footnoteAccentText)
        view.view.valueView.image = R.image.iconChevronRight()?.tinted(with: R.color.colorIconSecondary()!)

        view.innerInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 12)
    }

    func bind(locale: Locale) {
        view.view.titleView.text = R.string(preferredLanguages: locale.rLanguages
        ).localizable.multistakingMoreOptions()
    }
}
