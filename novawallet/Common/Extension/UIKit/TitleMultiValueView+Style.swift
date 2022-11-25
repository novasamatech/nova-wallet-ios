import Foundation

extension TitleMultiValueView {
    func applyDoubleValueBlurStyle() {
        titleLabel.textColor = R.color.colorTextSecondary()
        titleLabel.font = .p1Paragraph

        valueTop.textColor = R.color.colorTextPrimary()
        valueTop.font = .p1Paragraph

        valueBottom.textColor = R.color.colorTextSecondary()
        valueBottom.font = .p2Paragraph

        borderView.strokeColor = R.color.colorDivider()!
    }

    func applySingleValueBlurStyle() {
        titleLabel.textColor = R.color.colorTextSecondary()
        titleLabel.font = .p1Paragraph

        valueTop.textColor = R.color.colorTextPrimary()
        valueTop.font = .p1Paragraph

        borderView.strokeColor = R.color.colorDivider()!
    }
}
