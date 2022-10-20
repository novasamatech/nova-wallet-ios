import UIKit
import SoraUI

extension RoundedView.Style {
    static let roundedSelectableCell = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        strokeColor: .clear,
        highlightedStrokeColor: .clear,
        fillColor: R.color.colorWhite8()!,
        highlightedFillColor: R.color.colorAccentSelected()!,
        rounding: .init(radius: 12, corners: .allCorners)
    )
    static let roundedView = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        strokeColor: .clear,
        highlightedStrokeColor: .clear,
        fillColor: R.color.colorWhite8()!,
        highlightedFillColor: .clear,
        rounding: .init(radius: 12, corners: .allCorners)
    )
}
