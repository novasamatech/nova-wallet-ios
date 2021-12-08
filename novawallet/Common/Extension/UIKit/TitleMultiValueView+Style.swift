import Foundation

extension TitleMultiValueView {
    func applyBlurStyle() {
        titleLabel.textColor = R.color.colorTransparentText()
        titleLabel.font = .p1Paragraph

        valueTop.textColor = R.color.colorWhite()
        valueTop.font = .p1Paragraph

        valueBottom.textColor = R.color.colorTransparentText()
        valueBottom.font = .p2Paragraph

        borderView.strokeColor = R.color.colorWhite16()!
    }
}
