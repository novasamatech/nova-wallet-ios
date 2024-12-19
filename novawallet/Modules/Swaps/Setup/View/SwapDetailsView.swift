import UIKit

final class SwapDetailsView: CollapsableContainerView {
    let rateCell: SwapInfoViewCell = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
        $0.contentInsets = .init(top: 8, left: 16, bottom: 8, right: 16)
        $0.borderView.borderType = .bottom
        $0.roundedBackgroundView.cornerRadius = 12
        $0.roundedBackgroundView.roundingCorners = [.topLeft, .topRight]
    }

    let routeCell: SwapRouteViewCell = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
        $0.contentInsets = .init(top: 8, left: 16, bottom: 8, right: 16)
        $0.borderView.borderType = .bottom
        $0.roundedBackgroundView.cornerRadius = 0
    }

    let execTimeCell: SwapInfoViewCell = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
        $0.rowContentView.selectable = false
        $0.isUserInteractionEnabled = false
        $0.contentInsets = .init(top: 8, left: 16, bottom: 8, right: 16)
        $0.borderView.borderType = .bottom
        $0.roundedBackgroundView.cornerRadius = 0
    }

    let networkFeeCell: SwapNetworkFeeViewCell = .create {
        $0.contentInsets = .init(top: 8, left: 16, bottom: 8, right: 16)
        $0.borderView.borderType = .none
        $0.roundedBackgroundView.cornerRadius = 12
        $0.roundedBackgroundView.roundingCorners = [.bottomLeft, .bottomRight]
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundView.sideLength = 12
    }

    override var rows: [UIView] {
        [rateCell, routeCell, execTimeCell, networkFeeCell]
    }
}
