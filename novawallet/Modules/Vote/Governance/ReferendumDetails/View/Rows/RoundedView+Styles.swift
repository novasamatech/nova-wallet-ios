import UIKit
import SoraUI

extension RoundedView.Style {
    static let roundedLightCell = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        strokeColor: .clear,
        highlightedStrokeColor: .clear,
        fillColor: R.color.colorBlockBackground()!,
        highlightedFillColor: R.color.colorCellBackgroundPressed()!,
        rounding: .init(radius: 12, corners: .allCorners)
    )
    static let cellWithoutHighlighting = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        strokeColor: .clear,
        highlightedStrokeColor: .clear,
        fillColor: R.color.colorBlockBackground()!,
        highlightedFillColor: R.color.colorBlockBackground()!,
        rounding: .init(radius: 12, corners: .allCorners)
    )
}
