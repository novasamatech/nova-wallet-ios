import UIKit

final class StackNetworkFeeCell: RowView<NetworkFeeView> {
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

        borderView.strokeColor = R.color.colorWhite8()!

        isUserInteractionEnabled = false

        rowContentView.borderType = []
        rowContentView.style = NetworkFeeView.ViewStyle(
            titleColor: R.color.colorTransparentText()!,
            titleFont: .regularFootnote,
            tokenColor: R.color.colorWhite()!,
            tokenFont: .regularFootnote,
            fiatColor: R.color.colorTransparentText()!,
            fiatFont: .caption1
        )
    }
}

extension StackNetworkFeeCell: StackTableViewCellProtocol {}
