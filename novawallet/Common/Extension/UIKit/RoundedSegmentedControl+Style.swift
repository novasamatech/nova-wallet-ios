import UIKit
import UIKit_iOS

extension RoundedSegmentedControl {
    func applyPageSwitchStyle() {
        backgroundView.fillColor = R.color.colorSegmentedBackground()!
        selectionColor = R.color.colorSegmentedTabActive()!
        titleFont = .regularFootnote
        selectedTitleColor = R.color.colorTextPrimary()!
        titleColor = R.color.colorTextSecondary()!
    }
}
