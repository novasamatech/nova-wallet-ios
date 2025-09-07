import UIKit
import UIKit_iOS

final class DAppListHeaderView: UICollectionViewCell {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextPrimary()
        label.font = .boldLargeTitle
        return label
    }()

    let walletSwitch = WalletSwitchControl()

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
        titleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.tabbarDappsTitle_2_4_3()

        searchView.controlContentView.detailsLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.dappListSearch()
    }

    private func setupLayout() {
        contentView.addSubview(walletSwitch)
        walletSwitch.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(10.0)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.size.equalTo(UIConstants.walletSwitchSize)
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalTo(walletSwitch.snp.leading).offset(-8.0)
            make.centerY.equalTo(walletSwitch.snp.centerY)
        }

        contentView.addSubview(settingsButton)
        settingsButton.snp.makeConstraints { make in
            make.width.equalTo(44.0)
            make.height.equalTo(32.0)
            make.top.equalTo(titleLabel.snp.bottom).offset(12.0)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        contentView.addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalTo(settingsButton.snp.leading)
            make.top.equalTo(titleLabel.snp.bottom).offset(12.0)
            make.height.equalTo(36.0)
            make.bottom.equalToSuperview().inset(0.0)
        }
    }
}
