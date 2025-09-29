import UIKit
import UIKit_iOS

final class AHMInfoViewLayout: SCSingleActionLayoutView {
    let bannerContainer: UIView = .create { view in
        view.backgroundColor = .clear
    }

    let titleLabel: UILabel = .create { label in
        label.apply(style: .boldTitle3Primary)
        label.numberOfLines = 0
    }

    let subtitleLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
    }

    let featuresStackView: UIStackView = .create { view in
        view.axis = .vertical
        view.spacing = Constants.stackViewSpacing
        view.distribution = .fill
        view.alignment = .top
    }

    let infoStackView: UIStackView = .create { view in
        view.axis = .vertical
        view.spacing = Constants.stackViewSpacing
        view.distribution = .fill
        view.alignment = .leading
    }

    var actionButton: TriangularedButton {
        genericActionView
    }

    override func setupLayout() {
        super.setupLayout()
        addArrangedSubview(bannerContainer, spacingAfter: Constants.bannerToTitle)

        bannerContainer.snp.makeConstraints { make in
            make.height.equalTo(Constants.bannerInitialHeight)
        }

        addArrangedSubview(titleLabel, spacingAfter: Constants.titleToSubtitle)
        addArrangedSubview(subtitleLabel, spacingAfter: Constants.subtitleToFeatures)

        addArrangedSubview(featuresStackView, spacingAfter: Constants.featuresToSeparator)

        addArrangedSubview(createSeparator(), spacingAfter: Constants.separatorToInfo)

        addArrangedSubview(infoStackView)
    }

    override func setupStyle() {
        super.setupStyle()

        actionButton.applyDefaultStyle()
    }
}

// MARK: - Private

private extension AHMInfoViewLayout {
    func createSeparator() -> UIView {
        let separator = UIView.createSeparator()

        separator.snp.makeConstraints { make in
            make.height.equalTo(Constants.separatorHeight)
        }

        return separator
    }

    func addFeatureView(_ feature: AHMInfoViewModel.Feature) {
        let featureView: GenericPairValueView<UIView, UILabel> = .create { view in
            view.makeHorizontal()

            let emojiLabel = UILabel()

            emojiLabel.apply(style: .title3Primary)
            emojiLabel.textAlignment = .left

            view.fView.addSubview(emojiLabel)

            emojiLabel.snp.makeConstraints { make in
                make.top.leading.trailing.equalToSuperview()
                make.bottom.lessThanOrEqualToSuperview()
                make.height.equalTo(Constants.emojiLabelHeight)
            }

            view.sView.apply(style: .footnotePrimary)
            view.sView.numberOfLines = 0
            view.sView.textAlignment = .left

            view.spacing = Constants.featureIconToText

            emojiLabel.text = feature.emoji
            view.sView.text = feature.text
        }

        featuresStackView.addArrangedSubview(featureView)
    }

    func addInfoView(_ info: AHMInfoViewModel.Info) {
        let infoView: IconDetailsView = .create { view in
            view.detailsLabel.apply(style: .footnoteSecondary)
            view.detailsLabel.numberOfLines = 0
            view.spacing = Constants.infoIconToText
            view.iconWidth = Constants.iconWidth
        }

        let icon: UIImage? = switch info.type {
        case .history:
            R.image.iconHistoryGray18()
        case .migration:
            R.image.iconStarGray18()
        }

        infoView.imageView.image = icon
        infoView.detailsLabel.text = info.text

        infoStackView.addArrangedSubview(infoView)
    }

    func clearStacks() {
        [
            featuresStackView,
            infoStackView
        ].forEach { $0.arrangedSubviews.forEach { $0.removeFromSuperview() } }
    }
}

// MARK: - Internal

extension AHMInfoViewLayout {
    func bind(_ viewModel: AHMInfoViewModel) {
        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle

        clearStacks()

        viewModel.features.forEach { addFeatureView($0) }
        viewModel.info.forEach { addInfoView($0) }

        actionButton.imageWithTitleView?.title = viewModel.actionButtonTitle
    }

    func updateBannerHeight(_ height: CGFloat) {
        bannerContainer.snp.updateConstraints { make in
            make.height.equalTo(height)
        }
    }
}

// MARK: - Constants

private extension AHMInfoViewLayout {
    enum Constants {
        static let bannerToTitle: CGFloat = 16
        static let titleToSubtitle: CGFloat = 4
        static let subtitleToFeatures: CGFloat = 17
        static let featuresToSeparator: CGFloat = 13
        static let separatorToInfo: CGFloat = 10
        static let stackViewSpacing: CGFloat = 10
        static let featureIconToText: CGFloat = 16
        static let infoIconToText: CGFloat = 16
        static let bannerInitialHeight: CGFloat = 0
        static let separatorHeight: CGFloat = 1
        static let emojiLabelHeight: CGFloat = 24
        static let iconWidth: CGFloat = 18
    }
}
