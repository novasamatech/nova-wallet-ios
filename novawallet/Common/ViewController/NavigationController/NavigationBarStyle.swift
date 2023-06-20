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

        titleTextAttributes[.foregroundColor] = R.color.colorTextPrimary()!

        titleTextAttributes[.font] = UIFont.semiBoldBody

        return NavigationBarStyle(
            background: UIImage(),
            shadow: nil,
            shadowColor: nil,
            tintColor: R.color.colorTextPrimary()!,
            backImage: R.image.iconBack(),
            backgroundEffect: nil,
            titleAttributes: titleTextAttributes
        )
    }
}
