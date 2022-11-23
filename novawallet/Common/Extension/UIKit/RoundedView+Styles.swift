import Foundation
import SoraUI

extension RoundedView {
    func applyDisabledBackgroundStyle() {
        strokeColor = .clear
        highlightedStrokeColor = .clear
        fillColor = R.color.colorContainerBackground()!
        highlightedFillColor = R.color.colorContainerBackground()!
    }

    func applyEnabledBackgroundStyle() {
        strokeColor = R.color.colorContainerBorder()!
        highlightedStrokeColor = R.color.colorContainerBorder()!
        fillColor = .clear
        highlightedFillColor = .clear
    }

    func applyControlBackgroundStyle() {
        strokeColor = R.color.colorContainerBorder()!
        highlightedStrokeColor = .clear
        fillColor = .clear
        highlightedFillColor = R.color.colorCellBackgroundPressed()!
    }

    func applyCellBackgroundStyle() {
        shadowOpacity = 0.0
        strokeWidth = 0.0
        strokeColor = .clear
        highlightedStrokeColor = .clear
        fillColor = R.color.colorBlockBackground()!
        highlightedFillColor = R.color.colorCellBackgroundPressed()!
    }

    func applyFilledBackgroundStyle() {
        shadowOpacity = 0.0
        strokeWidth = 0.0
    }
}
