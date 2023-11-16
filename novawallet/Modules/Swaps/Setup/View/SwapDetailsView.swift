import UIKit

final class SwapDetailsView: CollapsableContainerView {
    let rateCell: SwapInfoViewCell = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
        $0.contentInsets = .init(top: 8, left: 16, bottom: 8, right: 16)
    }

    let networkFeeCell: SwapNetworkFeeViewCell = .create {
        $0.contentInsets = .init(top: 8, left: 16, bottom: 8, right: 16)
        $0.borderView.borderType = .none
    }

    override var rows: [UIView] {
        [rateCell, networkFeeCell]
    }
}
