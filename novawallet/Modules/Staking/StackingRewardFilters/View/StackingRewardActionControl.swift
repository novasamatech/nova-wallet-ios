import UIKit
import SoraUI

final class StackingRewardActionControl: UITableViewHeaderFooterView {
    let titleLabel = UILabel(style: .footnoteSecondary)
    let control: ActionTitleControl = .create {
        let tintColor = R.color.colorButtonTextAccent()!
        $0.titleLabel.apply(style: .footnoteAccent)
        $0.imageView.image = R.image.iconLinkChevron()?.tinted(with: tintColor)
        $0.identityIconAngle = CGFloat.pi / 2
        $0.activationIconAngle = -CGFloat.pi / 2
        $0.horizontalSpacing = 0
        $0.imageView.isUserInteractionEnabled = false
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let contentView = UIView.hStack(spacing: 4, [
            titleLabel,
            FlexibleSpaceView(),
            control
        ])

        addSubview(contentView)
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    func bind(title: String, value: String) {
        titleLabel.text = title
        control.titleLabel.text = value
        control.invalidateLayout()
        setNeedsLayout()
    }
}
