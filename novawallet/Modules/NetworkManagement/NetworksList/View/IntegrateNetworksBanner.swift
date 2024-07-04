import UIKit
import SnapKit
import SoraUI

class IntegrateNetworkBannerTableViewCell: PlainBaseTableViewCell<IntegrateNetworksBanner> {
    override func setupStyle() {
        super.setupStyle()

        backgroundColor = .clear
    }
}

protocol IntegrateNetworksBannerDekegate: AnyObject {
    func didTapClose()
}

final class IntegrateNetworksBanner: UIView {
    let gradientBannerView: GradientBannerView = .create {
        $0.infoView.imageView.image = R.image.imageBannerCircles()
        $0.stackView.setCustomSpacing(16, after: $0.infoView)
        $0.bind(model: .networkIntegration())
    }

    let closeButton: RoundedButton = .create {
        $0.roundedBackgroundView?.shadowOpacity = 0
        $0.roundedBackgroundView?.fillColor = R.color.colorBlockBackground()!
        $0.roundedBackgroundView?.highlightedFillColor = R.color.colorBlockBackground()!
        $0.roundedBackgroundView?.strokeColor = .clear
        $0.roundedBackgroundView?.highlightedStrokeColor = .clear
        $0.roundedBackgroundView?.cornerRadius = 12
        $0.imageWithTitleView?.iconImage = R.image.iconCloseWithBg()
        $0.changesContentOpacityWhenHighlighted = true
    }

    weak var delegate: IntegrateNetworksBannerDekegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()

        closeButton.addTarget(
            self,
            action: #selector(actionClose),
            for: .touchUpInside
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(gradientBannerView)
        gradientBannerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        addSubview(closeButton)
        closeButton.snp.makeConstraints {
            $0.size.equalTo(CGSize(width: 24, height: 24))
            $0.trailing.equalToSuperview().inset(16)
            $0.top.equalToSuperview().inset(16)
        }

        gradientBannerView.contentInsets = .init(top: 16, left: 16, bottom: 20, right: 0)
        gradientBannerView.infoView.imageInsets = .init(
            top: 24,
            left: 0,
            bottom: 0,
            right: 11
        )
    }

    func set(locale: Locale) {
        gradientBannerView.infoView.titleLabel.text = R.string.localizable.integrateNetworkBannerTitle(
            preferredLanguages: locale.rLanguages
        )
        gradientBannerView.infoView.subtitleLabel.text = R.string.localizable.integrateNetworkBannerMessage(
            preferredLanguages: locale.rLanguages
        )
        gradientBannerView.linkButton?.imageWithTitleView?.title = R.string.localizable.integrateNetworkBannerButtonLink(
            preferredLanguages: locale.rLanguages
        )
    }

    @objc private func actionClose() {
        delegate?.didTapClose()
    }
}
