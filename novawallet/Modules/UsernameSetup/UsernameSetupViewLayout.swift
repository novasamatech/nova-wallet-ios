import UIKit
import SnapKit
import SoraUI

final class UsernameSetupViewLayout: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .boldTitle2
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTransparentText()
        label.numberOfLines = 0
        return label
    }()

    let captionLabel: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorWhite48()
        label.numberOfLines = 0
        return label
    }()

    let walletNameTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTransparentText()
        return label
    }()

    let walletNameInputView = TextInputView()

    let proceedButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()
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
            make.top.equalTo(safeAreaLayoutGuide).inset(16.0)
        }

        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(titleLabel.snp.bottom).offset(8.0)
        }

        addSubview(walletNameTitleLabel)
        walletNameTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(16.0)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(walletNameInputView)
        walletNameInputView.snp.makeConstraints { make in
            make.top.equalTo(walletNameTitleLabel.snp.bottom).offset(8.0)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(captionLabel)
        captionLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(walletNameInputView.snp.bottom).offset(12.0)
        }

        addSubview(proceedButton)
        proceedButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
