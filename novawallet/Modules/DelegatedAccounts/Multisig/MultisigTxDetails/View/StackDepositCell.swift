import UIKit

final class StackDepositCell: RowView<TitleAmountView> {
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

        rowContentView.borderType = []
        rowContentView.style = NetworkFeeView.ViewStyle(
            titleColor: R.color.colorTextSecondary()!,
            titleFont: .regularFootnote,
            tokenColor: R.color.colorTextPrimary()!,
            tokenFont: .regularFootnote,
            fiatColor: R.color.colorTextSecondary()!,
            fiatFont: .caption1
        )

        rowContentView.titleView.imageView.image = R.image.iconLock()?
            .tinted(with: R.color.colorIconSecondary()!)
        rowContentView.titleView.detailsView.imageView.image = R.image.iconInfoFilled()
    }
}

extension StackDepositCell: StackTableViewCellProtocol {}
