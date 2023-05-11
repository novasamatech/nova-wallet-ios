import UIKit
import SoraUI

final class StackingRewardActionControl: StackingRewardControl<ActionTitleControl> {
    override func createControl() -> ActionTitleControl {
        let control = ActionTitleControl()
        let tintColor = R.color.colorButtonTextAccent()!
        control.titleLabel.apply(style: .footnoteAccent)
        control.imageView.image = R.image.iconLinkChevron()?.tinted(with: tintColor)
        control.identityIconAngle = CGFloat.pi / 2
        control.activationIconAngle = -CGFloat.pi / 2
        control.horizontalSpacing = 0
        control.imageView.isUserInteractionEnabled = false
        return control
    }

    func bind(title: String, value: String) {
        titleLabel.text = title
        control.titleLabel.text = value
        control.invalidateLayout()
        setNeedsLayout()
    }
}
