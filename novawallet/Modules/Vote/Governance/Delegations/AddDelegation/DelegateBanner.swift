import UIKit
import SnapKit

final class DelegateBanner: UIView {
    let bannerView: GradientBannerView = .create {
        $0.infoView.imageView.image = R.image.iconDelegateBadges()
        $0.bind(model: .stakingController())
    }

    let closeButton: UIButton = .create {
        let icon = R.image.iconClose()?.tinted(with: R.color.colorIconChip()!)
        $0.setImage(icon, for: .normal)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(bannerView)
        bannerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        addSubview(closeButton)
        closeButton.snp.makeConstraints {
            $0.size.equalTo(CGSize(width: 20, height: 20))
            $0.trailing.equalToSuperview().inset(8)
            $0.top.equalToSuperview().inset(12)
        }
    }
}
