import UIKit
import UIKit_iOS

final class GradientBannerTableViewCell: UITableViewCell {
    let gradientBannerView: GradientBannerView = .create {
        $0.infoView.imageView.image = R.image.iconBannerCriticalUpdate()
        $0.stackView.setCustomSpacing(8, after: $0.infoView)
        $0.showsLink = false
        $0.contentInsets = UIEdgeInsets(top: 16, left: 16, bottom: 36, right: 0)
        $0.bind(model: .criticalUpdate())
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        contentView.addSubview(gradientBannerView)
        gradientBannerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    func bind(isCritical: Bool, locale: Locale) {
        if isCritical {
            gradientBannerView.infoView.imageView.image = R.image.iconBannerCriticalUpdate()
            gradientBannerView.bind(model: .criticalUpdate())
            gradientBannerView.infoView.titleLabel.text =
                R.string(preferredLanguages: locale.rLanguages).localizable.inAppUpdatesBannerCriticalTitle()
            let subtitle = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.inAppUpdatesBannerCriticalSubtitle()
            gradientBannerView.infoView.subtitleLabel.text = subtitle
        } else {
            gradientBannerView.infoView.imageView.image = R.image.iconBannerMajorUpdate()
            gradientBannerView.bind(model: .majorUpdate())
            gradientBannerView.infoView.titleLabel.text =
                R.string(preferredLanguages: locale.rLanguages).localizable.inAppUpdatesBannerMajorTitle()
            let subtitle = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.inAppUpdatesBannerMajorSubtitle()
            gradientBannerView.infoView.subtitleLabel.text = subtitle
        }
    }
}
