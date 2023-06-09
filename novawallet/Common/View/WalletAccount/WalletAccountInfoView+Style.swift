import UIKit

extension WalletAccountInfoView {
    func applyOutlineStyle() {
        roundedBackgroundView.apply(style: .selectableContainer(radius: 12))

        contentInsets = UIEdgeInsets(top: 7.0, left: 12.0, bottom: 7.0, right: 16.0)
        actionIcon = R.image.iconMore()?.tinted(with: R.color.colorIconSecondary()!)
    }
}
