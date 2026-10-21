import UIKit
import UIKit_iOS

final class SubtensorShieldToggleView: RoundedView {
    let titleLabel: UILabel = .create {
        $0.apply(style: .footnotePrimary)
    }

    let subtitleLabel: UILabel = .create {
        $0.apply(style: .caption1Secondary)
        $0.numberOfLines = 0
    }

    let switchControl: UISwitch = .create {
        $0.onTintColor = R.color.colorIconAccent()
        $0.setContentHuggingPriority(.required, for: .horizontal)
        $0.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension SubtensorShieldToggleView {
    enum Constants {
        static let contentInsets = UIEdgeInsets(top: 13, left: 16, bottom: 13, right: 16)
        static let textSpacing: CGFloat = 2
        static let switchSpacing: CGFloat = 8
        static let cornerRadius: CGFloat = 12
    }

    func configureStyle() {
        applyFilledBackgroundStyle()
        fillColor = R.color.colorBlockBackground()!
        cornerRadius = Constants.cornerRadius
    }

    func setupLayout() {
        let textView = UIView.vStack(spacing: Constants.textSpacing, [titleLabel, subtitleLabel])

        let contentView = UIView.hStack(
            alignment: .center,
            spacing: Constants.switchSpacing,
            [textView, switchControl]
        )

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Constants.contentInsets)
        }
    }
}
