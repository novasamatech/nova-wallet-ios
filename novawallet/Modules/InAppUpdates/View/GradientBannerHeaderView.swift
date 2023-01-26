import UIKit
import SoraUI

final class GradientBannerHeaderView: UITableViewHeaderFooterView {
    let gradientBannerView: GradientBannerView = .create {
        $0.infoView.imageView.image = R.image.iconBannerCriticalUpdate()
        $0.stackView.setCustomSpacing(8, after: $0.infoView)
        $0.showsLink = false
        $0.bind(model: .criticalUpdate())
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

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

    func bind(isCritical: Bool, locale _: Locale) {
        if isCritical {
            gradientBannerView.infoView.imageView.image = R.image.iconBannerCriticalUpdate()
            gradientBannerView.bind(model: .criticalUpdate())
            gradientBannerView.infoView.titleLabel.text = "Critical update"
            gradientBannerView.infoView.subtitleLabel.text = "To avoid any issues, and improve your user experience, we strongly recommend that you install recent updates as soon as possible"
        } else {
            gradientBannerView.infoView.imageView.image = R.image.iconBannerMajorUpdate()
            gradientBannerView.bind(model: .majorUpdate())
            gradientBannerView.infoView.titleLabel.text = "Major update"
            gradientBannerView.infoView.subtitleLabel.text = "Lots of amazing new features are available for Nova Wallet with the recent updates! Make sure to update your application to access them!"
        }
    }
}
