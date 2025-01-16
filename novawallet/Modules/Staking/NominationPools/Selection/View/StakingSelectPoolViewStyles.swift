import UIKit_iOS

extension RoundedButton.Style {
    static let accentButton = RoundedButton.Style(
        background: .init(
            fillColor: R.color.colorButtonBackgroundPrimary()!,
            highlightedFillColor: R.color.colorButtonBackgroundPrimary()!
        ),
        title: .semiboldFootnoteButtonText
    )
    static let inactiveButton = RoundedButton.Style(
        background: .init(
            fillColor: R.color.colorButtonBackgroundInactive()!,
            highlightedFillColor: R.color.colorButtonBackgroundInactive()!
        ),
        title: .semiboldFootnoteButtonInactive
    )
}
