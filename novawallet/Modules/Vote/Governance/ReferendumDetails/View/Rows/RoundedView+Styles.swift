import UIKit
import SoraUI

extension RoundedView.Style {
    static let roundedLightCell = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        strokeColor: .clear,
        highlightedStrokeColor: .clear,
        fillColor: R.color.colorWhite8()!,
        highlightedFillColor: R.color.colorAccentSelected()!,
        rounding: .init(radius: 12, corners: .allCorners)
    )
    static let cellWithoutHighlighting = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        strokeColor: .clear,
        highlightedStrokeColor: .clear,
        fillColor: R.color.colorWhite8()!,
        highlightedFillColor: R.color.colorWhite8()!,
        rounding: .init(radius: 12, corners: .allCorners)
    )
}
