import Foundation

extension TitleAmountView {
    static func dark() -> TitleAmountView {
        let view = TitleAmountView()
        view.borderView.borderType = []
        view.verticalOffset = 13.0

        view.style = NetworkFeeView.ViewStyle(
            titleColor: R.color.colorTransparentText()!,
            titleFont: .regularFootnote,
            tokenColor: R.color.colorWhite()!,
            tokenFont: .regularFootnote,
            fiatColor: R.color.colorTransparentText()!,
            fiatFont: .caption1
        )

        return view
    }
}
