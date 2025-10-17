import UIKit
import UIKit_iOS

extension BorderedLabelView {
    struct Style {
        let text: UILabel.Style
        let background: RoundedView.Style
    }

    func apply(style: Style) {
        titleLabel.apply(style: style.text)
        backgroundView.apply(style: style.background)
    }
}

extension BorderedLabelView.Style {
    static let stepNumber = BorderedLabelView.Style(
        text: .init(
            textColor: R.color.colorTextSecondary()!,
            font: .semiBoldCaps1
        ),
        background: .init(
            shadowOpacity: 0,
            strokeWidth: 0,
            fillColor: R.color.colorRouteNumberBackground()!,
            highlightedFillColor: R.color.colorRouteNumberBackground()!
        )
    )

    static let chipsText = BorderedLabelView.Style(
        text: .init(
            textColor: R.color.colorChipText()!,
            font: .semiBoldCaps1
        ),
        background: .init(
            shadowOpacity: 0,
            strokeWidth: 0,
            fillColor: R.color.colorChipsBackground()!,
            highlightedFillColor: R.color.colorChipsBackground()!
        )
    )

    static let critical = BorderedLabelView.Style(
        text: .init(
            textColor: R.color.colorCriticalText()!,
            font: .semiBoldCaps2
        ),
        background: .init(
            shadowOpacity: 0,
            strokeWidth: 0,
            fillColor: R.color.colorCriticalChipBackground()!,
            highlightedFillColor: R.color.colorCriticalChipBackground()!
        )
    )

    static let major = BorderedLabelView.Style(
        text: .init(
            textColor: R.color.colorMajorChipText()!,
            font: .semiBoldCaps2
        ),
        background: .init(
            shadowOpacity: 0,
            strokeWidth: 0,
            fillColor: R.color.colorMajorChipBackground()!,
            highlightedFillColor: R.color.colorMajorChipBackground()!
        )
    )

    static let latest = BorderedLabelView.Style(
        text: .init(
            textColor: R.color.colorChipText()!,
            font: .semiBoldCaps2
        ),
        background: .init(
            shadowOpacity: 0,
            strokeWidth: 0,
            fillColor: R.color.colorChipsBackground()!,
            highlightedFillColor: R.color.colorChipsBackground()!
        )
    )

    static let new = BorderedLabelView.Style(
        text: .init(
            textColor: R.color.colorTextPositive()!,
            font: .semiBoldCaps2
        ),
        background: .init(
            shadowOpacity: 0,
            strokeWidth: 0,
            fillColor: R.color.colorChipsBackground()!,
            highlightedFillColor: R.color.colorChipsBackground()!
        )
    )

    static let legacy = BorderedLabelView.Style(
        text: .init(
            textColor: R.color.colorChipText()!,
            font: .semiBoldCaps2
        ),
        background: .init(
            shadowOpacity: 0,
            strokeWidth: 0,
            fillColor: R.color.colorChipsBackground()!,
            highlightedFillColor: R.color.colorChipsBackground()!
        )
    )
}
