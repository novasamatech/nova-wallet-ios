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

    func applyErrorStyle() {
        roundedBackgroundView?.apply(style: .strokeOnError)
        symbolLabel.apply(style: .semiboldBodyPrimary)
        textField.textColor = R.color.colorTextNegative()
        textField.tintColor = R.color.colorTextNegative()
        textField.font = .title2
        priceLabel.apply(style: .footnoteSecondary)
    }

    func applyNormalStyle() {
        roundedBackgroundView?.apply(style: .strokeOnEditing)
        symbolLabel.apply(style: .semiboldBodyPrimary)
        textField.textColor = R.color.colorTextPrimary()
        textField.tintColor = R.color.colorTextPrimary()
        textField.font = .title2
        priceLabel.apply(style: .footnoteSecondary)
    }
}
