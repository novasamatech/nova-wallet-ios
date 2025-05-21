import Foundation
import UIKit_iOS

extension RoundedButton {
    func setTitle(_ title: String?) {
        imageWithTitleView?.title = title
        invalidateLayout()
    }

    func setIcon(_ icon: UIImage?) {
        imageWithTitleView?.iconImage = icon
        invalidateLayout()
    }
}
