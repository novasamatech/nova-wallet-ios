import Foundation
import UIKit_iOS

extension RoundedButton.Style {
    static let operation = RoundedButton.Style(
        background: .icon,
        title: .init(
            textColor: R.color.colorTextPrimary()!,
            font: .semiBoldFootnote
        )
    )
}

extension RoundedView.Style {
    static let icon = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        strokeColor: .clear,
        highlightedStrokeColor: .clear,
        fillColor: .clear,
        highlightedFillColor: .clear,
        rounding: .init(radius: 0, corners: .allCorners)
    )
}

extension StackTitleMultiValueCell.Style {
    static let balancePart = StackTitleMultiValueCell.Style(
        title: .secondaryRow,
        value: .bigRowContrasted
    )
}

extension IconDetailsView.Style {
    static let secondaryRow = IconDetailsView.Style(
        tintColor: R.color.colorTextSecondary()!,
        font: .regularSubheadline
    )
}

extension StackTitleValueIconView.Style {
    static let balanceWidgetStaticPart = StackTitleValueIconView.Style(
        title: .boldTitle2Primary,
        value: .regularSubhedlineSecondary,
        icon: R.image.iconSmallArrowDown()?
            .tinted(with: R.color.colorIconChip()!)?
            .withAlignmentRectInsets(.init(inset: -4)),
        iconBorderStyle: .chips,
        adjustsFontSizeToFitWidth: true
    )
}
