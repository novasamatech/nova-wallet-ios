import UIKit

final class DAppListFeaturedHeaderView: UICollectionViewCell {
    static let preferredHeight: CGFloat = 64.0

    let titleLabel: UILabel = {
        let view = UILabel()
        view.font = .semiBoldTitle3
        view.textColor = R.color.colorWhite()
        return view
    }()

    let actionButton: TriangularedBlurButton = {
        let button = TriangularedBlurButton()
        button.imageWithTitleView?.iconImage = R.image.iconAssetsSettings()?
            .withRenderingMode(.alwaysTemplate)
            .tinted(with: R.color.colorWhite80()!)
        button.contentInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        button.changesContentOpacityWhenHighlighted = true
        button.triangularedBlurView?.overlayView.highlightedFillColor =
            R.color.colorAccentSelected()!
        return button
    }()

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                setupLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupLocalization()
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        layoutAttributes.frame.size = CGSize(width: layoutAttributes.frame.width, height: Self.preferredHeight)
        return layoutAttributes
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLocalization() {
        titleLabel.text = R.string.localizable.dappListFeaturedWebsites(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        addSubview(actionButton)

        actionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.lessThanOrEqualTo(actionButton.snp.leading).offset(-8.0)
            make.centerY.equalToSuperview()
        }
    }
}
