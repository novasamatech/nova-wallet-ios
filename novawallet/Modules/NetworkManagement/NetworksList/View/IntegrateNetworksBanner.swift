import UIKit
import SnapKit
import UIKit_iOS

class IntegrateNetworkBannerTableViewCell: PlainBaseTableViewCell<IntegrateNetworksBanner> {
    override func setupStyle() {
        super.setupStyle()

        backgroundColor = .clear
    }
}

protocol IntegrateNetworksBannerDelegate: AnyObject {
    func didTapClose()
    func didTapIntegrateNetwork()
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

    weak var delegate: IntegrateNetworksBannerDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()

        closeButton.addTarget(
            self,
            action: #selector(actionClose),
            for: .touchUpInside
        )

        gradientBannerView.linkButton?.addTarget(
            self,
            action: #selector(actionLink),
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
            top: -15,
            left: 0,
            bottom: 0,
            right: 11
        )

        gradientBannerView.infoView.textInsets = .init(
            top: 0,
            left: 0,
            bottom: 0,
            right: 50
        )
    }

    private func setupStyle() {
        gradientBannerView.infoView.titleLabel.apply(style: .semiboldSubhedlinePrimary)
        gradientBannerView.infoView.subtitleLabel.apply(style: .caption1Primary)
    }

    func set(locale: Locale) {
        gradientBannerView.infoView.titleLabel.text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable().integrateNetworkBannerTitle()
        gradientBannerView.infoView.subtitleLabel.text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.integrateNetworkBannerMessage()
        gradientBannerView.linkButton?.imageWithTitleView?.title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.integrateNetworkBannerButtonLink()
    }

    @objc private func actionClose() {
        delegate?.didTapClose()
    }

    @objc private func actionLink() {
        delegate?.didTapIntegrateNetwork()
    }
}
