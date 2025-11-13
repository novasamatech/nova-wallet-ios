import UIKit
import UIKit_iOS

extension RoundedView {
    struct Style: Equatable {
        var shadow: ShadowShapeView.Style?
        var strokeWidth: CGFloat?
        var strokeColor: UIColor?
        var highlightedStrokeColor: UIColor?
        var fillColor: UIColor
        var highlightedFillColor: UIColor
        var rounding: Rounding?

        struct Rounding: Equatable {
            let radius: CGFloat
            let corners: UIRectCorner
        }

        init(
            shadowOpacity: Float? = nil,
            strokeWidth: CGFloat? = nil,
            strokeColor: UIColor? = nil,
            highlightedStrokeColor: UIColor? = nil,
            fillColor: UIColor,
            highlightedFillColor: UIColor,
            rounding: RoundedView.Style.Rounding? = nil
        ) {
            if let shadowOpacity = shadowOpacity {
                shadow = ShadowShapeView.Style(
                    shadowOpacity: shadowOpacity,
                    shadowColor: nil,
                    shadowRadius: nil,
                    shadowOffset: nil
                )
            } else {
                shadow = nil
            }
            self.strokeWidth = strokeWidth
            self.strokeColor = strokeColor
            self.highlightedStrokeColor = highlightedStrokeColor
            self.fillColor = fillColor
            self.highlightedFillColor = highlightedFillColor
            self.rounding = rounding
        }

        init(
            shadow: ShadowShapeView.Style,
            strokeWidth: CGFloat? = nil,
            strokeColor: UIColor? = nil,
            highlightedStrokeColor: UIColor? = nil,
            fillColor: UIColor,
            highlightedFillColor: UIColor,
            rounding: RoundedView.Style.Rounding? = nil
        ) {
            self.shadow = shadow
            self.strokeWidth = strokeWidth
            self.strokeColor = strokeColor
            self.highlightedStrokeColor = highlightedStrokeColor
            self.fillColor = fillColor
            self.highlightedFillColor = highlightedFillColor
            self.rounding = rounding
        }
    }

    func apply(style: Style) {
        style.shadow.map { apply(style: $0) }
        style.strokeWidth.map { strokeWidth = $0 }
        style.strokeColor.map { strokeColor = $0 }
        style.highlightedStrokeColor.map { highlightedStrokeColor = $0 }

        fillColor = style.fillColor
        highlightedFillColor = style.highlightedFillColor

        style.rounding.map {
            roundingCorners = $0.corners
            cornerRadius = $0.radius
        }
    }
}

extension RoundedView.Style {
    static let chips = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        fillColor: R.color.colorChipsBackground()!,
        highlightedFillColor: R.color.colorChipsBackground()!
    )

    static let chipsOnCard = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        fillColor: R.color.colorChipsOnCardBackground()!,
        highlightedFillColor: R.color.colorChipsOnCardBackground()!
    )

    static func roundedChips(radius: CGFloat) -> RoundedView.Style {
        var chipsStyle = RoundedView.Style.chips
        chipsStyle.rounding = .init(radius: radius, corners: .allCorners)
        return chipsStyle
    }

    static func rounded(radius: CGFloat) -> RoundedView.Style {
        RoundedView.Style(
            shadowOpacity: 0,
            strokeWidth: 0,
            fillColor: .clear,
            highlightedFillColor: .clear,
            rounding: .init(radius: radius, corners: .allCorners)
        )
    }

    static let container = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0.5,
        strokeColor: R.color.colorContainerBorder(),
        highlightedStrokeColor: R.color.colorContainerBorder(),
        fillColor: R.color.colorContainerBackground()!,
        highlightedFillColor: R.color.colorContainerBackground()!
    )

    static let containerWithShadow = RoundedView.Style(
        shadow: .init(
            shadowOpacity: 1,
            shadowColor: R.color.colorIconBackgroundShadow()!,
            shadowRadius: 12,
            shadowOffset: CGSize(width: 0, height: 2)
        ),
        strokeWidth: 0.5,
        strokeColor: R.color.colorContainerBorder(),
        highlightedStrokeColor: R.color.colorContainerBorder(),
        fillColor: R.color.colorContainerBackground()!,
        highlightedFillColor: R.color.colorContainerBackground()!
    )

    static func selectableContainer(radius: CGFloat) -> RoundedView.Style {
        RoundedView.Style(
            shadowOpacity: 0,
            strokeWidth: 1,
            strokeColor: R.color.colorContainerBorder(),
            highlightedStrokeColor: R.color.colorContainerBorder(),
            fillColor: R.color.colorContainerBackground()!,
            highlightedFillColor: R.color.colorCellBackgroundPressed()!,
            rounding: .init(radius: radius, corners: .allCorners)
        )
    }

    static func outlineSelectableContainer(radius: CGFloat) -> RoundedView.Style {
        RoundedView.Style(
            shadowOpacity: 0,
            strokeWidth: 1,
            strokeColor: R.color.colorContainerBorder(),
            highlightedStrokeColor: R.color.colorContainerBorder(),
            fillColor: .clear,
            highlightedFillColor: R.color.colorCellBackgroundPressed()!,
            rounding: .init(radius: radius, corners: .allCorners)
        )
    }

    static func roundedContainer(radius: CGFloat) -> RoundedView.Style {
        var containerStyle = RoundedView.Style.container
        containerStyle.rounding = .init(radius: radius, corners: .allCorners)
        return containerStyle
    }

    static func roundedContainerWithShadow(radius: CGFloat) -> RoundedView.Style {
        var containerStyle = RoundedView.Style.containerWithShadow
        containerStyle.rounding = .init(radius: radius, corners: .allCorners)
        return containerStyle
    }

    static let tokenContainer = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0.5,
        strokeColor: R.color.colorContainerBorder(),
        highlightedStrokeColor: R.color.colorContainerBorder(),
        fillColor: R.color.colorContainerBackground()!,
        highlightedFillColor: R.color.colorContainerBackground()!
    )

    static let assetContainer = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0.5,
        strokeColor: R.color.colorContainerBorder(),
        highlightedStrokeColor: R.color.colorContainerBorder(),
        fillColor: R.color.colorTokenContainerBackground()!,
        highlightedFillColor: R.color.colorTokenContainerBackground()!
    )

    static let searchBarTextField = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        fillColor: R.color.colorInputBackground()!,
        highlightedFillColor: R.color.colorInputBackground()!
    )

    static let textField = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 1,
        strokeColor: R.color.colorInputBackground(),
        highlightedStrokeColor: R.color.colorActiveBorder(),
        fillColor: R.color.colorInputBackground()!,
        highlightedFillColor: R.color.colorInputBackground()!,
        rounding: .init(radius: 12, corners: .allCorners)
    )

    static let inputStrokeOnCardEditing = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        strokeColor: R.color.colorContainerBorder(),
        highlightedStrokeColor: .clear,
        fillColor: .clear,
        highlightedFillColor: .clear,
        rounding: .init(radius: 12, corners: .allCorners)
    )

    static let strokeOnEditing = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        strokeColor: R.color.colorActiveBorder(),
        highlightedStrokeColor: R.color.colorActiveBorder(),
        fillColor: R.color.colorInputBackground()!,
        highlightedFillColor: R.color.colorInputBackground()!,
        rounding: .init(radius: 12, corners: .allCorners)
    )

    static let inputDisabled = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 1,
        strokeColor: R.color.colorContainerBorder(),
        highlightedStrokeColor: R.color.colorContainerBorder(),
        fillColor: R.color.colorInputBackground()!,
        highlightedFillColor: R.color.colorInputBackground()!,
        rounding: .init(radius: 12, corners: .allCorners)
    )

    static let strokeOnError = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 1,
        strokeColor: R.color.colorBorderError(),
        highlightedStrokeColor: R.color.colorBorderError(),
        fillColor: R.color.colorInputBackground()!,
        highlightedFillColor: R.color.colorInputBackground()!,
        rounding: .init(radius: 12, corners: .allCorners)
    )

    static let clear = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        strokeColor: .clear,
        highlightedStrokeColor: .clear,
        fillColor: .clear,
        highlightedFillColor: .clear
    )

    static let divider = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        strokeColor: R.color.colorDivider(),
        highlightedStrokeColor: .clear,
        fillColor: .clear,
        highlightedFillColor: .clear,
        rounding: .init(radius: 0, corners: .allCorners)
    )
}

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

extension ShadowShapeView {
    struct Style: Equatable {
        let shadowOpacity: Float?
        let shadowColor: UIColor?
        let shadowRadius: CGFloat?
        let shadowOffset: CGSize?
    }

    func apply(style: Style) {
        style.shadowOpacity.map { shadowOpacity = $0 }
        style.shadowColor.map { shadowColor = $0 }
        style.shadowRadius.map { shadowRadius = $0 }
        style.shadowOffset.map { shadowOffset = $0 }
    }
}
