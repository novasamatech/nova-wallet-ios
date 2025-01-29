import Foundation

final class CollatorStkFullUnstakeSetupLayout: CollatorStkBaseUnstakeSetupLayout {
    override func setupLayout() {
        super.setupLayout()

        amountInputView.isUserInteractionEnabled = false
        amountInputView.applyDisabledStyle()
    }
}
