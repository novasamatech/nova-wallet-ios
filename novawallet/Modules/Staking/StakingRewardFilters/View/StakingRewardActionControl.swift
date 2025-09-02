import UIKit
import UIKit_iOS

final class StakingRewardActionControl: UITableViewHeaderFooterView {
    let titleLabel = UILabel(style: .footnoteSecondary)
    let control: ActionTitleControl = .create {
        let tintColor = R.color.colorButtonTextAccent()!
        $0.titleLabel.apply(style: .footnoteAccentText)
        $0.imageView.image = R.image.iconLinkChevron()?.tinted(with: tintColor)
        $0.identityIconAngle = CGFloat.pi / 2
        $0.activationIconAngle = -CGFloat.pi / 2
        $0.horizontalSpacing = 0
        $0.imageView.isUserInteractionEnabled = false
    }

    lazy var bodyView = UIView.hStack(spacing: 4, [
        titleLabel,
        FlexibleSpaceView(),
        control
    ])

    var contentInsets = UIEdgeInsets.zero {
        didSet {
            bodyView.snp.updateConstraints {
                $0.edges.equalToSuperview().inset(contentInsets)
            }
        }
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
        contentView.addSubview(bodyView)
        bodyView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
        }
    }

    func bind(title: String, value: String, activated: Bool) {
        titleLabel.text = title
        control.titleLabel.text = value
        control.invalidateLayout()
        if control.isActivated != activated {
            activated ? control.activate(animated: true) : control.deactivate(animated: true)
        }
        setNeedsLayout()
    }
}
