import Foundation
import UIKit

struct NavigationBarStyle {
    let background: UIImage?
    let shadow: UIImage?
    let shadowColor: UIColor?
    let tintColor: UIColor?
    let backImage: UIImage?
    let backgroundEffect: UIBlurEffect?
    let titleAttributes: [NSAttributedString.Key: Any]?
}

extension NavigationBarStyle {
    static var defaultStyle: NavigationBarStyle {
        var titleTextAttributes = [NSAttributedString.Key: Any]()

        titleTextAttributes[.foregroundColor] = R.color.colorWhite()!

        titleTextAttributes[.font] = UIFont.h3Title

        return NavigationBarStyle(
            background: UIImage(),
            shadow: nil,
            shadowColor: nil,
            tintColor: R.color.colorWhite()!,
            backImage: R.image.iconBack(),
            backgroundEffect: nil,
            titleAttributes: titleTextAttributes
        )
    }
}
