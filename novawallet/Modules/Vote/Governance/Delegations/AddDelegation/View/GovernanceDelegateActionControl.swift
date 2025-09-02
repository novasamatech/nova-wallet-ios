import UIKit
import UIKit_iOS

final class GovernanceDelegateActionControl: UIView {
    let label = UILabel(style: .footnoteSecondary)

    let control: ActionTitleControl = .create {
        let tintColor = R.color.colorTextPrimary()!
        $0.titleLabel.apply(style: .footnotePrimary)
        $0.imageView.image = R.image.iconLinkChevron()?.tinted(with: tintColor)
        $0.identityIconAngle = CGFloat.pi / 2.0
        $0.activationIconAngle = -CGFloat.pi / 2.0
        $0.titleLabel.apply(style: .footnotePrimary)
        $0.horizontalSpacing = 0.0
        $0.imageView.isUserInteractionEnabled = false
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
        let contentView = UIView.hStack(spacing: 4, [
            label,
            control
        ])

        addSubview(contentView)
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    func bind(title: String, value: String) {
        label.text = title + ":"

        control.titleLabel.text = value
        control.invalidateLayout()

        setNeedsLayout()
    }
}
