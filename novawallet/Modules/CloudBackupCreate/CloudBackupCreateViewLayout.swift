import UIKit

final class CloudBackupCreateViewLayout: SCLoadableActionLayoutView {
    let titleView: MultiValueView = .create { view in
        view.valueTop.apply(style: .title3Primary)
        view.valueBottom.apply(style: .regularSubhedlineSecondary)
        view.valueBottom.numberOfLines = 0
        view.spacing = 8
    }

    let enterPasswordView: PasswordInputView = .create { view in
        view.textField.returnKeyType = .next
    }

    let confirmPasswordView: PasswordInputView = .create { view in
        view.textField.returnKeyType = .done
    }

    let hintView = HintListView()
    
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
