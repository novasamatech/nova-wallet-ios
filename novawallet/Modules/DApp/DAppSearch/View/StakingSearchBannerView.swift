import UIKit

final class StakingSearchBannerView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextPrimary()
        label.font = .regularFootnote
        label.numberOfLines = 0
        return label
    }()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        button.contentInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlockBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(titleLabel)
        addSubview(actionButton)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(12.0)
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.lessThanOrEqualTo(actionButton.snp.leading).offset(-12.0)
        }

        actionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.height.equalTo(32.0)
        }

        actionButton.setContentHuggingPriority(.required, for: .horizontal)
        actionButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(56.0)
        }

        let bottomConstraint = titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12.0)
        bottomConstraint.isActive = true
    }
}
