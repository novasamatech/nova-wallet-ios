import UIKit
import SoraUI

final class YourWalletsControlView: UIView {
    let iconView: UIImageView = .create {
        $0.contentMode = .center
    }

    let actionControl: ActionTitleControl = .create {
        let color = R.color.colorNovaBlue()!
        $0.imageView.image = R.image.iconLinkChevron()?.tinted(with: color)
        $0.identityIconAngle = CGFloat.pi / 2.0
        $0.activationIconAngle = -CGFloat.pi / 2.0
        $0.titleLabel.textColor = color
        $0.titleLabel.font = .caption1
        $0.horizontalSpacing = 0
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
        let stackView = UIStackView(arrangedSubviews: [
            iconView,
            actionControl
        ])
        stackView.alignment = .center
        stackView.spacing = 5

        addSubview(stackView)
        stackView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    override var intrinsicContentSize: CGSize {
        .init(width: UIView.noIntrinsicMetric, height: 26)
    }
}

extension YourWalletsControlView {
    struct Model {
        let name: String
        let image: UIImage?
    }

    func bind(model: Model) {
        actionControl.titleLabel.text = model.name
        iconView.image = model.image

        actionControl.invalidateLayout()
        setNeedsLayout()
    }
}
