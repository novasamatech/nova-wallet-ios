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
        view.spacing = 10
        view.distribution = .fill
        view.alignment = .leading
    }

    let infoStackView: UIStackView = .create { view in
        view.axis = .vertical
        view.spacing = 10
        view.distribution = .fill
        view.alignment = .leading
    }

    var actionButton: TriangularedButton {
        genericActionView
    }

    override func setupLayout() {
        super.setupLayout()
        addArrangedSubview(bannerContainer, spacingAfter: 16)

        bannerContainer.snp.makeConstraints { make in
            make.height.equalTo(0)
        }

        addArrangedSubview(titleLabel, spacingAfter: 4)
        addArrangedSubview(subtitleLabel, spacingAfter: 12)

        addArrangedSubview(featuresStackView, spacingAfter: 16)
        addArrangedSubview(infoStackView, spacingAfter: 12)
    }

    override func setupStyle() {
        super.setupStyle()

        actionButton.applyDefaultStyle()
    }
}

// MARK: - Private

private extension AHMInfoViewLayout {
    func addFeatureView(_ feature: AHMInfoViewModel.Feature) {
        let featureView: GenericPairValueView<UILabel, UILabel> = .create { view in
            view.makeHorizontal()

            view.fView.apply(style: .title3Primary)
            view.fView.textAlignment = .left

            view.sView.apply(style: .footnotePrimary)
            view.sView.numberOfLines = 0
            view.sView.textAlignment = .left

            view.spacing = 12
        }

        featureView.fView.text = feature.emoji
        featureView.sView.text = feature.text

        featuresStackView.addArrangedSubview(featureView)
    }

    func addInfoView(_ info: AHMInfoViewModel.Info) {
        let infoView: IconDetailsView = .create { view in
            view.detailsLabel.apply(style: .footnoteSecondary)
            view.detailsLabel.numberOfLines = 0
            view.spacing = 16
            view.iconWidth = 18
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
