import UIKit
import SoraUI

final class SwapPairView: UIView {
    let leftAssetView = SwapElementView()
    let rigthAssetView = SwapElementView()

    let arrowView: UIImageView = .create {
        $0.backgroundColor = R.color.colorSecondaryScreenBackground()
        $0.layer.cornerRadius = 24
        $0.image = R.image.iconForward()
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
        let stackView = UIView.hStack(distribution: .fillEqually, [
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
}
