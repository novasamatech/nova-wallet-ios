import UIKit

final class SelectValidatorsViewLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.alignment = .fill
        return view
    }()

    var stackView: UIStackView {
        contentView.stackView
    }

    let bannerView: GradientBannerView = {
        let view = GradientBannerView()
        view.showsAction = true
        view.infoView.imageView.image = R.image.iconBannerStar()
        view.bind(model: .stakingValidators())
        return view
    }()

    let customValidatorsCell: StackTableCell = {
        let view = StackTableCell()
        view.titleLabel.textColor = R.color.colorWhite()
        view.titleLabel.font = .regularSubheadline
        view.detailsLabel.textColor = R.color.colorTransparentText()
        view.detailsLabel.font = .regularSubheadline
        view.rowContentView.valueView.spacing = 8.0
        view.rowContentView.valueView.mode = .detailsIcon
        view.iconImageView.image = R.image.iconSmallArrow()?.tinted(
            with: R.color.colorTransparentText()!
        )
        view.preferredHeight = 52.0
        view.isUserInteractionEnabled = true

        view.roundedBackgroundView.fillColor = R.color.colorWhite8()!
        view.roundedBackgroundView.roundingCorners = .allCorners
        view.roundedBackgroundView.cornerRadius = 12.0

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
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }

        stackView.addArrangedSubview(bannerView)
        bannerView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
        }

        stackView.setCustomSpacing(16.0, after: bannerView)

        stackView.addArrangedSubview(customValidatorsCell)
    }
}
