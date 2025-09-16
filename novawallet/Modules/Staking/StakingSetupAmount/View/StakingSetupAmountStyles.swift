import UIKit

extension BorderedLabelView.Style {
    static let counter = BorderedLabelView.Style(
        text: .init(
            textColor: R.color.colorTextSecondary()!,
            font: .semiBoldCaps2
        ),
        background: .init(
            shadowOpacity: 0,
            strokeWidth: 0,
            fillColor: R.color.colorBlockBackground()!,
            highlightedFillColor: R.color.colorBlockBackground()!,
            rounding: .init(radius: 6, corners: .allCorners)
        )
    )
}
