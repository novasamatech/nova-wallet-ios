import UIKit
import UIKit_iOS

final class ImportCloudPasswordViewLayout: SCLoadableActionLayoutView {
    let titleLabel: UILabel = .create { label in
        label.apply(style: .boldTitle3Primary)
        label.numberOfLines = 0
    }

    let subtitleLabel: UILabel = .create { label in
        label.apply(style: .regularSubhedlineSecondary)
        label.numberOfLines = 0
    }

    let passwordView: PasswordInputView = .create { view in
        view.textField.returnKeyType = .done
        view.textField.textContentType = .password
    }

    let forgetPasswordButton: RoundedButton = .create { button in
        button.applyTextStyle()
    }

    var actionButton: TriangularedButton {
        genericActionView.actionButton
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(titleLabel, spacingAfter: 8)
        addArrangedSubview(subtitleLabel, spacingAfter: 24)
        addArrangedSubview(passwordView, spacingAfter: 10)

        let forgetPasswordContentView = UIView.hStack(
            alignment: .fill,
            distribution: .fill,
            spacing: 0,
            margins: nil,
            [forgetPasswordButton, UIView()]
        )

        addArrangedSubview(forgetPasswordContentView)

        forgetPasswordButton.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
    }
}
