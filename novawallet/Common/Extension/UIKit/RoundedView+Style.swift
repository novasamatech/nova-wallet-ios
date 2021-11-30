import Foundation
import SoraUI

extension RoundedView {
    func applyDisabledBackgroundStyle() {
        strokeColor = .clear
        highlightedStrokeColor = .clear
        fillColor = R.color.colorDarkGray()!
        highlightedFillColor = R.color.colorDarkGray()!
    }

    func applyEnabledBackgroundStyle() {
        strokeColor = R.color.colorTransparentText()!
        highlightedStrokeColor = R.color.colorTransparentText()!
        fillColor = .clear
        highlightedFillColor = .clear
    }
}
