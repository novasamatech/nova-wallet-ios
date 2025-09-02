import Foundation
import UIKit_iOS

public struct ModalCardPresentationStyle {
    public let backdropColor: UIColor

    public init(backdropColor: UIColor) {
        self.backdropColor = backdropColor
    }
}

public extension ModalCardPresentationStyle {
    static var defaultStyle: ModalCardPresentationStyle {
        ModalCardPresentationStyle(backdropColor: UIColor.darkGray.withAlphaComponent(0.3))
    }
}
