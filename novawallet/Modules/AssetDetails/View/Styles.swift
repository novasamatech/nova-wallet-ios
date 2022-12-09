import Foundation

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
