import Foundation

extension TitleAmountView {
    static func dark() -> TitleAmountView {
        let view = TitleAmountView()
        view.borderView.borderType = []
        view.verticalOffset = 13.0

        view.style = NetworkFeeView.ViewStyle(
            titleColor: R.color.colorTextSecondary()!,
            titleFont: .regularFootnote,
            tokenColor: R.color.colorTextPrimary()!,
            tokenFont: .regularFootnote,
            fiatColor: R.color.colorTextSecondary()!,
            fiatFont: .caption1
        )

        return view
    }
}
