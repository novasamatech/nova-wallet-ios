import UIKit
import SoraUI

final class DAppListHeaderView: UICollectionViewCell {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h1Title
        return label
    }()

    let accountButton: RoundedButton = {
        let button = RoundedButton()
        button.applyIconStyle()
        return button
    }()

    let decorationView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.layer.cornerRadius = 12.0
        view.clipsToBounds = true
        view.image = R.image.imageDapps()
        return view
    }()

    let decorationTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h2Title
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    let decorationSubtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .p2Paragraph
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    let searchView: ControlView<TriangularedBlurView, IconDetailsView> = {
        let backgroundView = TriangularedBlurView()
        backgroundView.overlayView.highlightedFillColor = R.color.colorAccentSelected()!

        let contentView = IconDetailsView()
        contentView.imageView.image = R.image.iconSearch()?.withRenderingMode(.alwaysTemplate)
        contentView.tintColor = R.color.colorWhite48()
        contentView.detailsLabel.textColor = R.color.colorWhite48()
        contentView.detailsLabel.font = .p1Paragraph
        contentView.detailsLabel.numberOfLines = 0

        return ControlView(backgroundView: backgroundView, contentView: contentView, preferredHeight: 52.0)
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
        titleLabel.text = R.string.localizable.tabbarDappsTitle_2_4_3(
            preferredLanguages: selectedLocale.rLanguages
        )

        decorationTitleLabel.text = R.string.localizable.dappDecorationTitle_2_4_3(
            preferredLanguages: selectedLocale.rLanguages
        )

        decorationSubtitleLabel.text = R.string.localizable.dappsDecorationSubtitle_2_4_3(
            preferredLanguages: selectedLocale.rLanguages
        )

        searchView.controlContentView.detailsLabel.text = R.string.localizable.dappListSearch(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    private func setupLayout() {
        contentView.addSubview(accountButton)
        accountButton.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(10.0)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.size.equalTo(UIConstants.navigationAccountIconSize)
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalTo(accountButton.snp.leading).offset(-8.0)
            make.centerY.equalTo(accountButton.snp.centerY)
        }

        contentView.addSubview(decorationView)
        decorationView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(accountButton.snp.bottom).offset(16.0)
        }

        decorationView.addSubview(decorationTitleLabel)
        decorationTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(24.0)
        }

        decorationView.addSubview(decorationSubtitleLabel)
        decorationSubtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(decorationTitleLabel.snp.bottom).offset(8.0)
            make.bottom.equalToSuperview().inset(24.0)
        }

        contentView.addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(decorationView.snp.bottom).offset(12.0)
            make.height.equalTo(52.0)
            make.bottom.equalToSuperview().inset(0.0)
        }
    }
}
