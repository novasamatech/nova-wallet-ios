import UIKit
import UIKit_iOS

final class ConsentBannerUpgradeViewLayout: UIView {
    let titleLabel: UILabel = .create { label in
        label.font = .boldTitle2
        label.textColor = R.color.colorTextPrimary()
        label.numberOfLines = 0
        label.textAlignment = .center
    }

    let descriptionLabel: UILabel = .create { label in
        label.font = .regularSubheadline
        label.textColor = R.color.colorTextSecondary()
        label.numberOfLines = 0
        label.textAlignment = .center
    }

    let consentLabel: UILabel = .create { label in
        label.isUserInteractionEnabled = true
        label.numberOfLines = 0
        label.textAlignment = .natural
    }

    let consentCheckbox: UIButton = .create { button in
        button.setImage(R.image.iconCheckboxEmpty(), for: .normal)
        button.setImage(R.image.iconCheckbox(), for: .selected)
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        button.accessibilityIdentifier = "consentBannerUpgradeCheckbox"
    }

    let acceptButton: TriangularedButton = .create { button in
        button.applyDefaultStyle()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(Constants.titleTopInset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Constants.descriptionTopGap)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(acceptButton)
        acceptButton.snp.makeConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-Constants.acceptBottomInset)
            make.centerX.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(consentLabel)
        consentLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.consentLeadingInset)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(acceptButton.snp.top).offset(-Constants.consentBottomGap)
        }

        addSubview(consentCheckbox)
        consentCheckbox.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(consentLabel.snp.top)
            make.width.height.equalTo(Constants.checkboxSize)
        }
    }
}

private extension ConsentBannerUpgradeViewLayout {
    enum Constants {
        static let titleTopInset: CGFloat = 32
        static let descriptionTopGap: CGFloat = 16
        static let consentBottomGap: CGFloat = 24
        static let acceptBottomInset: CGFloat = 16
        static let checkboxSize: CGFloat = 24
        // 16 (screen inset) + 24 (checkbox) + 12 (gap) = 52
        static let consentLeadingInset: CGFloat = 52
    }
}
