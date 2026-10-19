import Foundation
import UIKit

public struct ModalCardPresentationConfiguration {
    public let style: ModalCardPresentationStyle

    public let extendUnderSafeArea: Bool
    public let dismissPercentThreshold: CGFloat
    public let dismissVelocityThreshold: CGFloat
    public let dismissMinimumOffset: CGFloat

    public init(
        style: ModalCardPresentationStyle = .defaultStyle,
        extendUnderSafeArea: Bool = false,
        dismissPercentThreshold: CGFloat = 0.35,
        dismissVelocityThreshold: CGFloat = 1280,
        dismissMinimumOffset: CGFloat = 87
    ) {
        self.style = style
        self.extendUnderSafeArea = extendUnderSafeArea
        self.dismissPercentThreshold = dismissPercentThreshold
        self.dismissVelocityThreshold = dismissVelocityThreshold
        self.dismissMinimumOffset = dismissMinimumOffset
    }

    public init(backdropOpacity: CGFloat) {
        let style = ModalCardPresentationStyle(
            backdropColor: UIColor.white.withAlphaComponent(backdropOpacity)
        )

        self.init(style: style)
    }
}
