import UIKit

extension WalletAccountInfoView {
    func applyOutlineStyle() {
        roundedBackgroundView.fillColor = .clear
        roundedBackgroundView.highlightedFillColor = R.color.colorHighlightedAccent()!
        roundedBackgroundView.strokeWidth = 1.0
        roundedBackgroundView.strokeColor = R.color.colorWhite16()!
        roundedBackgroundView.highlightedStrokeColor = .clear
        roundedBackgroundView.cornerRadius = 12.0

        contentInsets = UIEdgeInsets(top: 7.0, left: 12.0, bottom: 7.0, right: 16.0)
        actionIcon = R.image.iconInfo()?.tinted(with: R.color.colorWhite48()!)
    }
}
