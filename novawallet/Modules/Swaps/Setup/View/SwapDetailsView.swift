import UIKit

final class SwapDetailsView: CollapsableContainerView {
    let rateCell: SwapRateView = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
        $0.titleView.imageWithTitleView?.iconImage = R.image.iconInfoFilledAccent()
        $0.addBottomSeparator()
    }

    let networkFeeCell = SwapNetworkFeeView(frame: .zero)

    override var rows: [UIView] {
        [rateCell, networkFeeCell]
    }
}
