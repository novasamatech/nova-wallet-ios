import UIKit

final class AssetListRevealCell: CollectionViewContainerCell<AssetListRevealView> {
    override init(frame: CGRect) {
        super.init(frame: frame)

        changesContentOpacityWhenHighlighted = true
    }

    func bind(hasHiddenAssets: Bool, locale: Locale) {
        view.bind(hasHiddenAssets: hasHiddenAssets, locale: locale)
    }
}

final class AssetListRevealView: UIView {
    let searchImageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
        view.image = R.image.iconSearchButton()?
            .withRenderingMode(.alwaysTemplate)
            .tinted(with: R.color.colorIconSecondary()!)
    }

    let titleLabel: UILabel = .create { view in
        view.numberOfLines = 1
    }

    let accessoryImageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
        view.image = R.image.iconSmallArrow()?
            .withRenderingMode(.alwaysTemplate)
            .tinted(with: R.color.colorIconSecondary()!)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(hasHiddenAssets: Bool, locale: Locale) {
        titleLabel.attributedText = createTitle(
            hasHiddenAssets: hasHiddenAssets,
            locale: locale
        )
    }
}

// MARK: Private

private extension AssetListRevealView {
    func setupLayout() {
        addSubview(searchImageView)
        searchImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.contentInset)
            make.size.equalTo(Constants.iconSize)
            make.centerY.equalToSuperview()
        }

        addSubview(accessoryImageView)
        accessoryImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Constants.contentInset)
            make.size.equalTo(Constants.iconSize)
            make.centerY.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(searchImageView.snp.trailing).offset(Constants.contentSpacing)
            make.trailing.equalTo(accessoryImageView.snp.leading).offset(-Constants.contentSpacing)
            make.centerY.equalToSuperview()
        }
    }

    func createTitle(
        hasHiddenAssets: Bool,
        locale: Locale
    ) -> NSAttributedString {
        let languages = locale.rLanguages

        let manageTitle = NSAttributedString(
            string: R.string(preferredLanguages: languages).localizable.tokensManageTitle(),
            attributes: [
                .font: UIFont.regularSubheadline,
                .foregroundColor: R.color.colorButtonTextAccent()!
            ]
        )

        guard hasHiddenAssets else {
            return manageTitle
        }

        let missingToken = R.string(preferredLanguages: languages).localizable.walletListMissingToken()

        let title = NSMutableAttributedString(
            string: missingToken + " ",
            attributes: [
                .font: UIFont.regularSubheadline,
                .foregroundColor: R.color.colorTextSecondary()!
            ]
        )

        title.append(manageTitle)

        return title
    }
}

// MARK: Constants

private extension AssetListRevealView {
    enum Constants {
        static let contentInset: CGFloat = UIConstants.horizontalInset + 4
        static let contentSpacing: CGFloat = 12
        static let iconSize: CGFloat = 24
    }
}
