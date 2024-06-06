import UIKit

final class CloudBackupCreateViewLayout: SCLoadableActionLayoutView {
    let titleView: MultiValueView = .create { view in
        view.valueTop.apply(style: .title3Primary)
        view.valueTop.textAlignment = .left
        view.valueBottom.apply(style: .regularSubhedlineSecondary)
        view.valueBottom.textAlignment = .left
        view.valueBottom.numberOfLines = 0
        view.spacing = 8
    }

    let enterPasswordView: PasswordInputView = .create { view in
        view.textField.returnKeyType = .next
    }

    let confirmPasswordView: PasswordInputView = .create { view in
        view.textField.returnKeyType = .done
    }

    let hintView: HintListView = .create { view in
        view.style = .init(
            itemAlignment: .center,
            iconWidth: 16,
            iconContentMode: .scaleAspectFit
        )
    }

    override func setupStyle() {
        super.setupStyle()

        genericActionView.actionButton.applyDefaultStyle()
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(titleView, spacingAfter: 24)
        addArrangedSubview(enterPasswordView, spacingAfter: 16)
        addArrangedSubview(confirmPasswordView, spacingAfter: 16)
        addArrangedSubview(hintView)
    }
}
