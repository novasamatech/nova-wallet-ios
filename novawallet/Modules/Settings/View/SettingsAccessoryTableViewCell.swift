import UIKit

class SettingsAccessoryTableViewCell<A: UIView>: SettingsTableViewCell {
    let accessoryDisplayView = A()

    override func setupLayout() {
        super.setupLayout()

        contentStackView?.insertArranged(view: accessoryDisplayView, before: accessoryArrowView)
    }
}
