import UIKit
import UIKit_iOS

final class DAppStakingBannerView: UIView {
    let titleLabel: UILabel = .create { view in
        view.apply(style: .footnotePrimary)
        view.numberOfLines = 2
    }

    let actionButton: RoundedButton = .create { view in
        view.applyPrimaryStyle()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlockBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Internal

extension DAppStakingBannerView {
    func bind(message: String, actionTitle: String) {
        titleLabel.text = message
        actionButton.imageWithTitleView?.title = actionTitle
        actionButton.invalidateLayout()
    }
}

// MARK: Private

private extension DAppStakingBannerView {
    func setupLayout() {
        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        actionButton.setContentHuggingPriority(.required, for: .horizontal)
        actionButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.horizontalInset)
            make.trailing.lessThanOrEqualTo(actionButton.snp.leading).offset(-Constants.contentSpacing)
            make.centerY.equalToSuperview()
        }
    }
}

// MARK: Constants

private extension DAppStakingBannerView {
    enum Constants {
        static let horizontalInset: CGFloat = 16.0
        static let contentSpacing: CGFloat = 12.0
    }
}
