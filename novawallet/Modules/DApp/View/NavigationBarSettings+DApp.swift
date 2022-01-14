import Foundation
import UIKit

extension NavigationBarSettings {
    static var dappSettings: NavigationBarSettings {
        var titleTextAttributes = [NSAttributedString.Key: Any]()

        titleTextAttributes[.foregroundColor] = R.color.colorWhite()!

        titleTextAttributes[.font] = UIFont.h3Title

        let style = NavigationBarStyle(
            background: UIImage(),
            shadow: UIImage(),
            shadowColor: nil,
            tintColor: R.color.colorWhite(),
            backImage: R.image.iconBack(),
            backgroundEffect: UIBlurEffect(style: .dark),
            titleAttributes: titleTextAttributes
        )

        return NavigationBarSettings(style: style, shouldSetCloseButton: false)
    }
}
