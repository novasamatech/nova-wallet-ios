import UIKit

final class StackingRewardSwitchControl: StackingRewardControl<UISwitch> {
    override func createControl() -> UISwitch {
        let switchView = UISwitch()
        switchView.onTintColor = R.color.colorIconAccent()
        return switchView
    }

    func bind(title: String, value: Bool) {
        titleLabel.text = title
        control.isOn = value
        setNeedsLayout()
    }
}
