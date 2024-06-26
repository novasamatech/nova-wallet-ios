import UIKit

final class OnboardingWalletReadyViewLayout: UIView {
    let titleLabel: UILabel = .create { label in
        label.font = .boldTitle3
        label.textColor = R.color.colorTextPrimary()
        label.textAlignment = .center
    }

    let subtitleLabel: UILabel = .create { label in
        label.font = .semiBoldSubheadline
        label.textColor = R.color.colorTextSecondary()
        label.numberOfLines = 0
        label.textAlignment = .center
    }

    let nameView: WalletNameView = .create { view in
        view.walletNameInputView.isUserInteractionEnabled = false
        view.walletNameInputView.shouldUseClearButton = false
    }

    var walletNameInputView: TextInputView {
        nameView.walletNameInputView
    }

    let cloudBackupActionView: LoadableActionView = .create { view in
        view.actionButton.imageWithTitleView?.iconImage = R.image.iconAppleLogo()
        view.actionButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 4
        view.actionButton.applyCloudBackupEnabledStyle()
        view.actionLoadingView.applyDisableButtonStyle()
    }

    var cloudBackupButton: TriangularedButton {
        cloudBackupActionView.actionButton
    }

    let manualBackupButton: TriangularedButton = .create { button in
        button.applySecondaryDefaultStyle()
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
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(safeAreaLayoutGuide).inset(46)
        }

        addSubview(nameView)
        nameView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(titleLabel.snp.bottom).offset(24)
            make.height.equalTo(200)
        }

        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(nameView.snp.bottom).offset(40)
        }

        addSubview(manualBackupButton)
        manualBackupButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(cloudBackupActionView)
        cloudBackupActionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(manualBackupButton.snp.top).offset(-12)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
