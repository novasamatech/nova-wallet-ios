import UIKit
import SnapKit
import UIKit_iOS

final class UsernameSetupViewLayout: UIView {
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

    let nameView = WalletNameView()

    var walletNameInputView: TextInputView {
        nameView.walletNameInputView
    }

    let proceedButton: TriangularedButton = .create { button in
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

        addSubview(proceedButton)
        proceedButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
