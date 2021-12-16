import Foundation

extension TitleMultiValueView {
    func applyDoubleValueBlurStyle() {
        titleLabel.textColor = R.color.colorTransparentText()
        titleLabel.font = .p1Paragraph

        valueTop.textColor = R.color.colorWhite()
        valueTop.font = .p1Paragraph

        valueBottom.textColor = R.color.colorTransparentText()
        valueBottom.font = .p2Paragraph

        borderView.strokeColor = R.color.colorWhite16()!
    }

    func applySingleValueBlurStyle() {
        titleLabel.textColor = R.color.colorTransparentText()
        titleLabel.font = .p1Paragraph

        valueTop.textColor = R.color.colorWhite()
        valueTop.font = .p1Paragraph

        borderView.strokeColor = R.color.colorWhite16()!
    }
}
