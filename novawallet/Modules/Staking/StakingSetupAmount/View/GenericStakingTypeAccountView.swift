import UIKit

class GenericStakingTypeAccountView<T>: RowView<
    GenericTitleValueView<GenericPairValueView<T, MultiValueView>, UIImageView>
> where T: UIView {
    var titleLabel: UILabel { rowContentView.titleView.sView.valueTop }
    var subtitleLabel: UILabel { rowContentView.titleView.sView.valueBottom }
    var disclosureImageView: UIImageView { rowContentView.valueView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        roundedBackgroundView.apply(style: .roundedLightCell)
        preferredHeight = 52
        contentInsets = .init(top: 9, left: 16, bottom: 9, right: 14)
        borderView.borderType = .none

        titleLabel.textAlignment = .left
        subtitleLabel.textAlignment = .left
        titleLabel.apply(style: .footnotePrimary)
        subtitleLabel.apply(style: .init(
            textColor: R.color.colorTextPositive(),
            font: .caption1
        ))
        disclosureImageView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorTextSecondary()!)
        rowContentView.titleView.makeHorizontal()
        rowContentView.titleView.stackView.alignment = .center
        rowContentView.titleView.spacing = 12
        rowContentView.titleView.sView.spacing = 2
    }
}
