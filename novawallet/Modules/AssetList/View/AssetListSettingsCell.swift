import UIKit

final class AssetListSettingsCell: UICollectionViewCell {
    let titleLabel: UILabel = {
        let view = UILabel()
        view.font = .semiBoldTitle3
        view.textColor = R.color.colorTextPrimary()
        return view
    }()

    let manageButton = BadgedManageButton()

    let searchButton: TriangularedButton = {
        let button = TriangularedButton()
        button.imageWithTitleView?.iconImage = R.image.iconSearchButton()
        button.triangularedView?.fillColor = .clear
        button.triangularedView?.highlightedFillColor = .clear
        button.triangularedView?.shadowOpacity = 0
        button.contentInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        button.changesContentOpacityWhenHighlighted = true

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
        addSubview(manageButton)

        manageButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        addSubview(searchButton)

        searchButton.snp.makeConstraints { make in
            make.trailing.equalTo(manageButton.snp.leading).inset(-4.0)
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
