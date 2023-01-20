import UIKit

final class DelegationsControlView: UIView {
    let label = UILabel(style: .footnoteSecondary)
    let control: YourWalletsControl = .create {
        $0.color = R.color.colorTextPrimary()!
        $0.iconDetailsView.detailsLabel.apply(style: .footnotePrimary)
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

        control.iconDetailsView.iconWidth = 0
        control.iconDetailsView.spacing = 0
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(contentView)
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    func bind(title: String, value: String) {
        label.text = title
        control.bind(model: .init(name: value, image: nil))
    }
}
