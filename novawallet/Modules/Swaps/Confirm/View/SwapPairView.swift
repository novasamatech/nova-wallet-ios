import UIKit
import UIKit_iOS

final class SwapPairView: UIView {
    let leftAssetView = SwapElementView()
    let rigthAssetView = SwapElementView()

    let arrowView: RoundedButton = .create {
        $0.imageWithTitleView?.iconImage = R.image.iconForward()
        $0.roundedBackgroundView?.apply(style: .icon)
        $0.roundedBackgroundView?.fillColor = R.color.colorSecondaryScreenBackground()!
        $0.roundedBackgroundView?.cornerRadius = 24
        $0.isUserInteractionEnabled = false
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

    private func setupLayout() {
        let stackView = UIView.hStack(distribution: .fillEqually, spacing: 8, [
            leftAssetView,
            rigthAssetView
        ])
        addSubview(stackView)
        addSubview(arrowView)

        stackView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        arrowView.snp.makeConstraints {
            $0.center.equalTo(stackView.snp.center)
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: max(
                leftAssetView.intrinsicContentSize.height,
                rigthAssetView.intrinsicContentSize.height
            )
        )
    }
}
