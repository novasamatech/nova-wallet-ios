import UIKit

final class AssetListSettingsCell: UICollectionViewCell {
    let titleLabel: UILabel = {
        let view = UILabel()
        view.font = .semiBoldTitle3
        view.textColor = R.color.colorWhite()
        return view
    }()

    let settingsButton: TriangularedBlurButton = {
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

    let searchButton: TriangularedBlurButton = {
        let button = TriangularedBlurButton()
        button.imageWithTitleView?.iconImage = R.image.iconSearchButton()?
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

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLocalization() {
        titleLabel.text = R.string.localizable.commonTokens(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        addSubview(settingsButton)

        settingsButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        addSubview(searchButton)

        searchButton.snp.makeConstraints { make in
            make.trailing.equalTo(settingsButton.snp.leading).inset(-8.0)
            make.centerY.equalToSuperview()
        }

        addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.lessThanOrEqualTo(searchButton.snp.leading).offset(-8.0)
            make.centerY.equalToSuperview()
        }
    }
}
