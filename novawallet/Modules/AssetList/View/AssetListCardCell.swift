import UIKit

final class AssetListCardView: ControlView<
    UIView,
    GenericTitleValueView<
        GenericPairValueView<UIImageView, UILabel>,
        UIImageView
    >
> {
    var iconView: UIImageView { controlContentView.titleView.fView }
    var titleLabel: UILabel { controlContentView.titleView.sView }
    var accessoryImageView: UIImageView { controlContentView.valueView }

    var locale: Locale = .current {
        didSet {
            if locale != oldValue {
                setupLocalization()
            }
        }
    }

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
        setupLocalization()
    }

    private func configure() {
        changesContentOpacityWhenHighlighted = true

        preferredHeight = 58
        contentInsets = UIEdgeInsets(top: 15, left: 12, bottom: 12, right: 16)

        controlContentView.spacing = 12
        controlContentView.titleView.setHorizontalAndSpacing(16)

        iconView.image = R.image.iconNovaCard()
        iconView.contentMode = .center

        accessoryImageView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
        accessoryImageView.contentMode = .center
    }

    private func setupLocalization() {
        let mainTitleString = NSAttributedString(
            string: R.string.localizable.commonManageDebitCard(preferredLanguages: locale.rLanguages),
            attributes: [
                .font: UIFont.regularBody,
                .foregroundColor: R.color.colorTextPrimary()!
            ]
        )

        titleLabel.attributedText = mainTitleString
    }
}
