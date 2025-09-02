import Foundation
import UIKit_iOS

extension RoundedView {
    func applyPrimaryButtonBackgroundStyle() {
        applyEnabledBackgroundStyle()

        fillColor = R.color.colorButtonBackgroundPrimary()!
    }

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
        shadowOpacity = .zero
        fillColor = .clear
        highlightedFillColor = R.color.colorCellBackgroundPressed()!
    }

    func applyBorderBackgroundStyle() {
        shadowOpacity = 0.0
        strokeColor = R.color.colorContainerBorder()!
        strokeWidth = 0.5
        highlightedStrokeColor = .clear
        fillColor = .clear
        highlightedFillColor = .clear
    }

    func applyCellBackgroundStyle() {
        shadowOpacity = 0.0
        strokeWidth = 0.0
        strokeColor = .clear
        highlightedStrokeColor = .clear
        fillColor = R.color.colorBlockBackground()!
        highlightedFillColor = R.color.colorCellBackgroundPressed()!
    }

    func applyErrorBlockBackgroundStyle() {
        let color = R.color.colorErrorBlockBackground()!
        applyFilledBackgroundStyle(for: color, highlighted: color)
    }

    func applyFilledBackgroundStyle() {
        shadowOpacity = 0.0
        strokeWidth = 0.0
    }

    func applyStrokedBackgroundStyle() {
        shadowOpacity = 0.0
        fillColor = .clear
        highlightedFillColor = .clear
    }

    func applyFilledBackgroundStyle(for color: UIColor, highlighted: UIColor) {
        shadowOpacity = 0.0
        strokeWidth = 0.0
        strokeColor = .clear
        highlightedStrokeColor = .clear
        fillColor = color
        highlightedFillColor = highlighted
    }
}
