import Foundation

extension NewAmountInputView {
    func applyDisabledStyle() {
        roundedBackgroundView?.apply(style: .inputDisabled)
        symbolLabel.apply(style: .semiboldBodySecondary)
        textField.textColor = R.color.colorTextSecondary()
        textField.tintColor = R.color.colorTextSecondary()
        textField.font = .title2
        priceLabel.apply(style: .footnoteSecondary)
    }
}
