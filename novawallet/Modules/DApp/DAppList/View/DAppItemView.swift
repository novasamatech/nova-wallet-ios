import UIKit
import SoraUI

protocol DAppItemViewDelegate: AnyObject {
    func dAppItemDidToggleFavorite(_ view: DAppItemView)
}

final class DAppItemView: UICollectionViewCell {
    private enum Constants {
        static let iconInsets = UIEdgeInsets(top: 6.0, left: 6.0, bottom: 6.0, right: 6.0)
        static let iconSize = CGSize(width: 36.0, height: 36.0)

        static var preferredIconViewSize: CGSize {
            CGSize(
                width: iconInsets.left + iconSize.width + iconInsets.right,
                height: iconInsets.top + iconSize.height + iconInsets.bottom
            )
        }
    }

    static let preferredHeight: CGFloat = 64.0

    weak var delegate: DAppItemViewDelegate?

    let favoriteButton: RoundedButton = {
        let button = RoundedButton()
        button.applyIconStyle()
        return button
    }()

    let iconImageView: DAppIconView = {
        let view = DAppIconView()
        view.contentInsets = Constants.iconInsets
        view.backgroundView.cornerRadius = 12.0
        view.backgroundView.strokeWidth = 0.5
        view.backgroundView.strokeColor = R.color.colorWhite16()!
        view.backgroundView.highlightedStrokeColor = R.color.colorWhite16()!
        view.backgroundView.fillColor = R.color.colorWhite8()!
        view.backgroundView.highlightedFillColor = R.color.colorWhite8()!
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .regularSubheadline
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .caption1
        return label
    }()

    let selectionView: RowView<UIView> = {
        let selectionView = RowView(contentView: UIView(), preferredHeight: DAppItemView.preferredHeight)
        selectionView.isUserInteractionEnabled = false
        selectionView.contentInsets = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )

        selectionView.rowContentView.backgroundColor = R.color.colorAccentSelected()
        selectionView.borderView.borderType = []

        return selectionView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        selectedBackgroundView = selectionView

        setupLayout()
        setupHandler()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        layoutAttributes.frame.size = CGSize(width: layoutAttributes.frame.width, height: Self.preferredHeight)
        return layoutAttributes
    }

    func setupHandler() {
        favoriteButton.addTarget(self, action: #selector(actionToggleFavorite), for: .touchUpInside)
    }

    func bind(viewModel: DAppViewModel) {
        iconImageView.bind(viewModel: viewModel.icon, size: Constants.iconSize)

        titleLabel.text = viewModel.name
        subtitleLabel.text = viewModel.details

        if viewModel.isFavorite {
            favoriteButton.imageWithTitleView?.iconImage = R.image.iconFavButtonSel()
        } else {
            favoriteButton.imageWithTitleView?.iconImage = R.image.iconFavButton()
        }

        favoriteButton.invalidateLayout()
    }

    private func setupLayout() {
        contentView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(32)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.preferredIconViewSize)
        }

        contentView.addSubview(favoriteButton)
        favoriteButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.height.equalToSuperview()
            make.width.equalTo(60.0)
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.top).offset(4.0)
            make.leading.equalTo(iconImageView.snp.trailing).offset(12.0)
            make.trailing.lessThanOrEqualTo(favoriteButton.snp.leading).offset(-4.0)
        }

        contentView.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(2.0)
            make.leading.equalTo(iconImageView.snp.trailing).offset(12.0)
            make.trailing.lessThanOrEqualTo(favoriteButton.snp.leading).offset(-4.0)
        }
    }

    @objc private func actionToggleFavorite() {
        delegate?.dAppItemDidToggleFavorite(self)
    }
}
