import Foundation
import SoraUI

public struct ModalCardPresentationStyle {
    public let backdropColor: UIColor

    public init(backdropColor: UIColor) {
        self.backdropColor = backdropColor
    }
}

public extension ModalCardPresentationStyle {
    static var defaultStyle: ModalCardPresentationStyle {
        ModalCardPresentationStyle(backdropColor: UIColor.white.withAlphaComponent(0.1))
    }
}
