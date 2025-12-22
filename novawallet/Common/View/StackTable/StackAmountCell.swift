import UIKit

typealias StackNetworkFeeCell = StackAmountCell<NetworkFeeView>
typealias StackGiftAmountCell = StackAmountCell<GiftAmountView>

class StackAmountCell<T: MultilineAmountView>: RowView<T>, StackTableViewCellProtocol {
    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
    }

    private func configureStyle() {
        preferredHeight = 44
        rowContentView.requiresFlexibleHeight()

        borderView.strokeColor = R.color.colorDivider()!

        isUserInteractionEnabled = false

        rowContentView.borderType = []
        rowContentView.style = TitleAmountView.ViewStyle(
            titleColor: R.color.colorTextSecondary()!,
            titleFont: .regularFootnote,
            tokenColor: R.color.colorTextPrimary()!,
            tokenFont: .regularFootnote,
            fiatColor: R.color.colorTextSecondary()!,
            fiatFont: .caption1
        )
    }
}
