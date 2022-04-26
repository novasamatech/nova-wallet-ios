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

    func applyControlBackgroundStyle() {
        strokeColor = R.color.colorTransparentText()!
        highlightedStrokeColor = .clear
        fillColor = .clear
        highlightedFillColor = R.color.colorAccentSelected()!
    }

    func applyCellBackgroundStyle() {
        shadowOpacity = 0.0
        strokeWidth = 0.0
        strokeColor = .clear
        highlightedStrokeColor = .clear
        fillColor = R.color.colorWhite8()!
        highlightedFillColor = R.color.colorAccentSelected()!
    }

    func applyFilledBackgroundStyle() {
        shadowOpacity = 0.0
        strokeWidth = 0.0
    }
}
