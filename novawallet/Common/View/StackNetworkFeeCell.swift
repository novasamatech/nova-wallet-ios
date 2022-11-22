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

        borderView.strokeColor = R.color.colorDivider()!

        isUserInteractionEnabled = false

        rowContentView.borderType = []
        rowContentView.style = NetworkFeeView.ViewStyle(
            titleColor: R.color.colorTextSecondary()!,
            titleFont: .regularFootnote,
            tokenColor: R.color.colorTextPrimary!,
            tokenFont: .regularFootnote,
            fiatColor: R.color.colorTextSecondary()!,
            fiatFont: .caption1
        )
    }
}

extension StackNetworkFeeCell: StackTableViewCellProtocol {}
