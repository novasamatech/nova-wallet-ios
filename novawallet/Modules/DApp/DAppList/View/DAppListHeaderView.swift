import UIKit
import UIKit_iOS

final class DAppListHeaderView: UICollectionViewCell {
    let searchView: ControlView<BlockBackgroundView, IconDetailsView> = {
        let backgroundView = BlockBackgroundView()
        backgroundView.overlayView?.highlightedFillColor = R.color.colorCellBackgroundPressed()!

        let contentView = IconDetailsView()
        contentView.imageView.image = R.image.iconSearch()
        contentView.detailsLabel.textColor = R.color.colorIconSecondary()
        contentView.detailsLabel.font = .p1Paragraph
        contentView.detailsLabel.numberOfLines = 0

        return ControlView(
            backgroundView: backgroundView,
            contentView: contentView,
            preferredHeight: 36.0
        )
    }()

    let settingsButton: TriangularedButton = {
        let button = TriangularedButton()
        button.imageWithTitleView?.iconImage = R.image.iconAssetsSettings()
        button.triangularedView?.fillColor = .clear
        button.triangularedView?.highlightedFillColor = .clear
        button.triangularedView?.shadowOpacity = 0
        button.contentInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        button.changesContentOpacityWhenHighlighted = true
        return button
    }()

    var selectedLocale = Locale.current {
        didSet {
            if selectedLocale != oldValue {
                setupLocalization()
            }
        }
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        let targetSize = CGSize(width: layoutAttributes.frame.width, height: 0)
        layoutAttributes.frame.size = contentView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return layoutAttributes
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLocalization() {
        searchView.controlContentView.detailsLabel.text = R.string.localizable.dappListSearch(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    private func setupLayout() {
        contentView.addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalToSuperview().inset(44 + UIConstants.horizontalInset)
            make.top.equalToSuperview().offset(12.0)
            make.bottom.equalToSuperview().inset(0.0)
        }

        contentView.addSubview(settingsButton)
        settingsButton.snp.makeConstraints { make in
            make.width.equalTo(44.0)
            make.height.equalTo(32.0)
            make.centerY.equalTo(searchView)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
    }
}
