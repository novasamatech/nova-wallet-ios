import UIKit
import UIKit_iOS

final class WalletManageTableViewCell<V: WalletViewProtocol>: WalletsListTableViewCell<V, UIImageView> {
    private lazy var reorderingAnimator = BlockViewAnimator()

    var disclosureIndicatorView: UIImageView { contentDisplayView.valueView }

    override func setupStyle() {
        super.setupStyle()

        let icon = R.image.iconSmallArrow()?.tinted(with: R.color.colorTextSecondary()!)
        disclosureIndicatorView.image = icon
        disclosureIndicatorView.setContentCompressionResistancePriority(.required, for: .horizontal)
        disclosureIndicatorView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }

    func setReordering(_ reordering: Bool, animated: Bool) {
        let closure = {
            self.disclosureIndicatorView.alpha = reordering ? 0.0 : 1.0
        }

        if animated {
            reorderingAnimator.animate(block: closure, completionBlock: nil)
        } else {
            closure()
        }

        if reordering {
            recolorReorderControl(R.color.colorIconPrimary()!)
        }
    }
}
